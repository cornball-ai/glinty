#' Send a text frame to a session's WebSocket
#'
#' Immediate framed write; the kernel socket buffer is the queue.
#' There is no concurrent writer in a single-threaded process, and
#' partial-write stalls are bounded by the connection timeout set at
#' accept. A failed write (surfaced by R as a warning) marks the
#' connection dead; the actual close happens at the top of the next
#' loop iteration.
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
    if (is.null(entry) || !identical(entry$state, "ws_open")) {
        return(invisible(FALSE))
    }
    ok <- TRUE
    tryCatch(
        withCallingHandlers(
            writeBin(ws_text_frame(text), entry$con),
            warning = function(w) {
                ok <<- FALSE
                invokeRestart("muffleWarning")
            }
        ),
        error = function(e) ok <<- FALSE
    )
    if (!ok) {
        mark_dead(key)
    }
    invisible(ok)
}
