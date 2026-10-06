# The single-threaded event loop. CivetWeb accepts, reads and frames
# on its own threads and queues events; each tick here fires due
# timers, flushes reactions, drains every session's outgoing queue,
# then sleeps in the transport's wait until the next events arrive.

#' Run the HTTP + WebSocket server loop
#'
#' Blocks until interrupted. Handlers connect the transport to the
#' app layer: on_request(req) returns a raw HTTP response (or NULL
#' for 404), on_open(session_id) / on_message(session_id, txt) /
#' on_close(session_id) manage sessions. Each loop tick fires due
#' timers, flushes reactions, and drains every session's outgoing
#' queue before sleeping in the transport's wait (timeout capped at
#' max_tick seconds so Ctrl-C stays responsive).
#'
#' @param port integer TCP port
#' @param handlers list of on_request, on_open, on_message, on_close
#' @param max_tick numeric maximum wait timeout in seconds
#' @param host character bind address, or NULL for every interface
#' @param tls_cert character PEM path, or NULL for plain http
#' @return invisible(NULL); runs until interrupt
#' @keywords internal
run_ws_server <- function(port, handlers, max_tick = 1, host = NULL,
                          tls_cert = NULL) {
    reg_reset()
    REG$transport <- transport_civetweb()
    REG$bound <- REG$transport$listen(port, host, tls_cert)
    on.exit(loop_shutdown(handlers), add = TRUE)

    tryCatch(
        repeat {
            loop_tick(handlers, max_tick)
        },
             interrupt = function(e) message("\nglinty server stopped.")
    )
    invisible(NULL)
}

#' One iteration of the event loop
#'
#' @param handlers the handler list
#' @param max_tick numeric maximum wait timeout in seconds
#' @return invisible(NULL)
#' @keywords internal
loop_tick <- function(handlers, max_tick) {
    # Deferred closes from failed writes, then timers, then the
    # reactive flush, then push everything queued out the door.
    for (key in REG$dead) {
        conn_close(key, notify = TRUE, handlers = handlers)
    }
    run_due_timers()
    flush_reactions()
    drain_all_sessions()
    # After the drain, so "flushed" means what it says: the messages
    # are on (or queued into) the wire. A fired callback has changed
    # state the client has not seen, so spin now rather than sleep.
    fired <- fire_on_flushed()

    tmo <- next_timer_deadline()
    if (is.null(tmo)) {
        tmo <- max_tick
    } else {
        tmo <- min(max_tick, max(tmo, 0))
    }
    if (fired > 0L) {
        tmo <- 0
    }

    REG$transport$wait(handlers, tmo)
    invisible(NULL)
}

#' Deliver a complete text payload to the app layer
#'
#' @param key character connection key
#' @param payload raw UTF-8 bytes
#' @param handlers the handler list
#' @return logical FALSE if the connection was failed
#' @keywords internal
ws_deliver <- function(key, payload, handlers) {
    txt <- tryCatch(rawToChar(payload), error = function(e) NULL)
    if (is.null(txt) || length(validUTF8(txt)) == 0L || !validUTF8(txt)) {
        ws_fail(key, 1007L, handlers)
        return(FALSE)
    }
    Encoding(txt) <- "UTF-8"
    entry <- REG$conns[[key]]
    if (!is.null(handlers$on_message) && !is.null(entry$session_id)) {
        handlers$on_message(entry$session_id, txt)
    }
    TRUE
}

#' Fail a WebSocket connection
#'
#' Best-effort close frame with the protocol error code, then close
#' and notify.
#'
#' @param key character connection key
#' @param code integer close code
#' @param handlers the handler list
#' @return invisible(NULL)
#' @keywords internal
ws_fail <- function(key, code, handlers) {
    conn_close(key, notify = TRUE, handlers = handlers, code = code)
    invisible(NULL)
}

#' Drain every live session's outgoing queue
#'
#' @return invisible(NULL)
#' @keywords internal
drain_all_sessions <- function() {
    for (sid in ls(.globals$sessions)) {
        s <- .globals$sessions[[sid]]
        if (!is.null(s)) {
            drain_session(s)
        }
    }
    invisible(NULL)
}

#' Shut the server down
#'
#' Closes every connection (1001 going away, with session teardown)
#' and the listener.
#'
#' @param handlers the handler list
#' @return invisible(NULL)
#' @keywords internal
loop_shutdown <- function(handlers) {
    for (key in names(REG$conns)) {
        conn_close(key, notify = TRUE, handlers = handlers, code = 1001L)
    }
    if (!is.null(REG$transport)) {
        REG$transport$close()
    }
    invisible(NULL)
}
