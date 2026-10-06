#' Send a text frame to a session's WebSocket
#'
#' Immediate write through the transport; the kernel socket buffer is
#' the queue. There is no concurrent writer in a single-threaded
#' process, and partial-write stalls are bounded by the connection
#' timeout. A failed write marks the connection dead; the actual close
#' happens at the top of the next loop iteration.
#'
#' @param session_id character session id
#' @param text character message (one JSON object)
#' @return logical success, invisibly
#' @keywords internal
send_to_session <- function(session_id, text) {
    key <- REG$sessions[[session_id]]
    if (is.null(key)) {
        return(invisible(FALSE))
    }
    entry <- REG$conns[[key]]
    if (is.null(entry) || !identical(entry$state, "ws_open") ||
        is.null(REG$transport)) {
        return(invisible(FALSE))
    }
    ok <- isTRUE(REG$transport$ws_send(entry, text))
    if (!ok) {
        mark_dead(key)
    }
    invisible(ok)
}
