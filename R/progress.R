#' Report progress during a long operation
#'
#' Runs expr with a progress bar visible on the client, then removes
#' it. Inside expr, call inc_progress() or set_progress() to advance.
#'
#' Each update is pushed to the client immediately rather than queued.
#' glinty runs one single-threaded event loop, so a blocking call
#' starves the normal drain and everything queued behind it would
#' arrive at once when the call returns -- a progress bar that jumps
#' straight from empty to gone. Updates only reach the browser between
#' blocking calls, so split long work into steps if you want the bar
#' to move.
#'
#' Browser-only: the native backend ignores progress messages.
#'
#' @param session a glinty_session
#' @param expr the work to run
#' @param message character headline shown on the bar
#' @param detail character secondary line
#' @param value numeric starting fraction between 0 and 1
#' @return the value of expr
#' @examples
#' \dontrun{
#' with_progress(session, message = "Transcribing...", {
#'     inc_progress(0.1, detail = "Preparing")
#'     wav <- ensure_wav(path)
#'     inc_progress(0.6, detail = "Running transcription")
#'     res <- stt.api::stt(wav)
#'     inc_progress(0.3, detail = "Done")
#'     res
#' })
#' }
#' @export
with_progress <- function(session, expr, message = "", detail = "", value = 0) {
    if (!inherits(session, "glinty_session")) {
        stop("session must be a glinty_session", call. = FALSE)
    }
    handle <- new.env(parent = emptyenv())
    handle$session <- session
    handle$id <- paste0("p", length(.globals$progress) + 1L, "-", session$id)
    handle$value <- clamp_progress(value)
    handle$message <- message
    handle$detail <- detail

    .globals$progress <- c(.globals$progress, list(handle))
    on.exit({
        .globals$progress <- drop_progress(handle)
        session$send(progress_msg("hide", handle))
        session$flush_now()
    }, add = TRUE)

    session$send(progress_msg("show", handle))
    session$flush_now()
    expr
}

#' Advance the current progress bar
#'
#' Adds amount to the bar opened by the innermost enclosing
#' with_progress(). Outside one it does nothing, so instrumented code
#' stays callable from a plain script.
#'
#' @param amount numeric fraction to add
#' @param detail character new secondary line (NULL leaves it alone)
#' @param message character new headline (NULL leaves it alone)
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' inc_progress(0.2, detail = "Converting audio")
#' }
#' @export
inc_progress <- function(amount = 0.1, detail = NULL, message = NULL) {
    handle <- current_progress()
    if (is.null(handle)) {
        return(invisible(NULL))
    }
    update_progress(handle, handle$value + amount, detail, message)
}

#' Set the current progress bar directly
#'
#' Like inc_progress() but takes an absolute fraction. Outside a
#' with_progress() it does nothing.
#'
#' @param value numeric fraction between 0 and 1 (NULL leaves it
#'   alone)
#' @param detail character new secondary line (NULL leaves it alone)
#' @param message character new headline (NULL leaves it alone)
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' set_progress(0.5, detail = "Halfway")
#' }
#' @export
set_progress <- function(value = NULL, detail = NULL, message = NULL) {
    handle <- current_progress()
    if (is.null(handle)) {
        return(invisible(NULL))
    }
    update_progress(handle, value, detail, message)
}

#' The innermost open progress handle
#'
#' The stack is global rather than session-scoped because the event
#' loop is single-threaded: only one with_progress() can be running
#' at any moment, so the top of the stack is unambiguous.
#'
#' @return a progress handle, or NULL when none is open
#' @keywords internal
current_progress <- function() {
    n <- length(.globals$progress)
    if (n == 0L) {
        return(NULL)
    }
    .globals$progress[[n]]
}

#' Remove one handle from the progress stack
#'
#' Removes by identity, so an inner bar closing out of order cannot
#' pop the wrong one.
#'
#' @param handle the handle to drop
#' @return the remaining stack
#' @keywords internal
drop_progress <- function(handle) {
    keep <- vapply(.globals$progress, function(h) !identical(h, handle),
                   logical(1L))
    .globals$progress[keep]
}

#' Apply an update to a progress handle and push it
#'
#' @param handle a progress handle
#' @param value numeric fraction, or NULL
#' @param detail character, or NULL
#' @param message character, or NULL
#' @return invisible(NULL)
#' @keywords internal
update_progress <- function(handle, value, detail, message) {
    if (!is.null(value)) {
        handle$value <- clamp_progress(value)
    }
    if (!is.null(detail)) {
        handle$detail <- detail
    }
    if (!is.null(message)) {
        handle$message <- message
    }
    handle$session$send(progress_msg("update", handle))
    handle$session$flush_now()
    invisible(NULL)
}

#' Hold a progress fraction inside [0, 1]
#'
#' @param value numeric
#' @return numeric in [0, 1]
#' @keywords internal
clamp_progress <- function(value) {
    value <- suppressWarnings(as.numeric(value))
    if (length(value) != 1L || !is.finite(value)) {
        return(0)
    }
    max(0, min(1, value))
}
