#' Send a message to app JavaScript
#'
#' The server-to-browser escape hatch, and the counterpart of
#' Glinty.setInputValue(). The client looks up handler among those
#' registered with Glinty.addCustomMessageHandler() and calls it with
#' value; an unregistered name logs a console warning rather than
#' failing, since handlers register asynchronously.
#'
#' The message is queued like any other and goes out on the next
#' flush. Registration order does not matter as long as the handler
#' exists by the time the message arrives -- register during the
#' glinty:connected event, which fires once per page load.
#'
#' Browser-only: the native backend has no JavaScript to receive it.
#'
#' @param session a glinty_session
#' @param handler character handler name registered on the client
#' @param value the payload; anything jsonlite can serialize. Scalars
#'   arrive unboxed, so TRUE becomes true rather than [true].
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' # server
#' observe_event(input$stream_mode, {
#'     send_custom_message(session, "set_stream_mode", input$stream_mode())
#' })
#'
#' # app JavaScript
#' # document.addEventListener("glinty:connected", function () {
#' #     Glinty.addCustomMessageHandler("set_stream_mode", function (on) {
#' #         streamMode = on;
#' #     });
#' # });
#' }
#' @export
send_custom_message <- function(session, handler, value = NULL) {
    if (!inherits(session, "glinty_session")) {
        stop("session must be a glinty_session", call. = FALSE)
    }
    if (!is.character(handler) || length(handler) != 1L ||
        !nzchar(handler)) {
        stop("handler must be a non-empty character string", call. = FALSE)
    }
    session$send(custom_msg(handler, value))
    invisible(NULL)
}
