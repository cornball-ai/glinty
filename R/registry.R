# Transport-side connection registry. Maps live socket connections to
# their state and sessions to connections. The session OBJECTS live in
# the reactive core (.globals$sessions); the transport only routes ids
# to sockets.

REG <- new.env(parent = emptyenv())

#' Reset the connection registry
#'
#' @return invisible(NULL)
#' @keywords internal
reg_reset <- function() {
    REG$conns <- list()
    REG$sessions <- list()
    REG$conn_counter <- 0L
    REG$dead <- character(0L)
    REG$srv <- NULL
    invisible(NULL)
}

#' Register a newly accepted connection
#'
#' @param con a socket connection (non-blocking, binary)
#' @param state character initial state ("http_pending")
#' @return character connection key
#' @keywords internal
conn_add <- function(con, state = "http_pending") {
    REG$conn_counter <- REG$conn_counter + 1L
    key <- sprintf("c%d", REG$conn_counter)
    entry <- new.env(parent = emptyenv())
    entry$con <- con
    entry$state <- state
    entry$buf <- raw(0L)
    entry$session_id <- NULL
    entry$frag_opcode <- NULL
    entry$frag_buf <- raw(0L)
    entry$opened_at <- Sys.time()
    REG$conns[[key]] <- entry
    key
}

#' Close a connection and clean up
#'
#' Idempotent. Sends a best-effort close frame on open WebSockets,
#' closes the socket, removes registry entries, and (when notify is
#' TRUE and a session was attached) fires the on_close handler so the
#' reactive core tears the session down.
#'
#' @param key character connection key
#' @param notify logical whether to fire on_close
#' @param handlers the event-loop handler list
#' @param code integer close code for the goodbye frame
#' @return invisible(NULL)
#' @keywords internal
conn_close <- function(key, notify, handlers, code = 1000L) {
    entry <- REG$conns[[key]]
    if (is.null(entry)) {
        return(invisible(NULL))
    }
    sid <- entry$session_id
    was_ws <- identical(entry$state, "ws_open")
    if (was_ws) {
        tryCatch(suppressWarnings(writeBin(ws_close_frame(code), entry$con)),
                 error = function(e) NULL)
    }
    tryCatch(close(entry$con), error = function(e) NULL)
    REG$conns[[key]] <- NULL
    REG$dead <- setdiff(REG$dead, key)
    if (!is.null(sid)) {
        REG$sessions[[sid]] <- NULL
    }
    if (was_ws && notify && !is.null(sid) && !is.null(handlers$on_close)) {
        tryCatch(handlers$on_close(sid), error = function(e) NULL)
    }
    invisible(NULL)
}

#' Mark a connection dead without closing it yet
#'
#' Used by the write path: closing mid-flush would mutate the
#' registry under the reactive core's feet, so the close is deferred
#' to the top of the next loop iteration.
#'
#' @param key character connection key
#' @return invisible(NULL)
#' @keywords internal
mark_dead <- function(key) {
    REG$dead <- union(REG$dead, key)
    invisible(NULL)
}

#' Rebind a connection to a different session id
#'
#' Resume support: a reconnecting client arrives on a fresh
#' connection under a fresh transport id; rebinding points the old
#' session id at the new connection so send_to_session() and event
#' routing keep working under the resumed identity.
#'
#' @param from_sid character transport id assigned at upgrade
#' @param to_sid character session id being resumed
#' @return logical success, invisibly
#' @keywords internal
transport_rebind <- function(from_sid, to_sid) {
    key <- REG$sessions[[from_sid]]
    if (is.null(key)) {
        return(invisible(FALSE))
    }
    REG$sessions[[from_sid]] <- NULL
    REG$sessions[[to_sid]] <- key
    entry <- REG$conns[[key]]
    if (!is.null(entry)) {
        entry$session_id <- to_sid
    }
    invisible(TRUE)
}

#' Generate a session id
#'
#' 32 hex characters from digest over pid, wall clock, a monotonic
#' counter, and a tempfile name. Deliberately NOT the R RNG: an
#' earlier save/restore-.Random.seed approach replayed the same draw
#' on every call after the first, so consecutive ids collided and
#' sessions swallowed each other's connections. The counter
#' guarantees in-process uniqueness. Within the resume grace window
#' the id acts as a weak credential; see ?run_app for scope.
#'
#' @return character session id
#' @keywords internal
new_session_id <- function() {
    if (is.null(REG$sid_counter)) {
        REG$sid_counter <- 0L
    }
    REG$sid_counter <- REG$sid_counter + 1L
    material <- paste(Sys.getpid(),
        sprintf("%.9f", as.numeric(Sys.time())),
        REG$sid_counter, tempfile(), sep = "|")
    substr(digest::digest(material, algo = "sha1", serialize = FALSE),
        1L, 32L)
}
