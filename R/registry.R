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

#' Generate a session id
#'
#' 32 hex characters. Restores .Random.seed so server traffic does
#' not perturb user RNG streams. The id is a routing label, never an
#' authenticator: a fresh WebSocket always gets a fresh session.
#'
#' @return character session id
#' @keywords internal
new_session_id <- function() {
    had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
    if (had_seed) {
        old_seed <- get(".Random.seed", envir = globalenv())
        on.exit(assign(".Random.seed", old_seed, envir = globalenv()))
    }
    paste(sprintf("%02x", sample.int(256L, 16L, replace = TRUE) - 1L),
          collapse = "")
}
