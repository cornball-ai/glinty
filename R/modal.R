#' Show a modal dialog
#'
#' Sends a dialog the client builds and overlays. The body and footer
#' are ordinary tag trees, so inputs and buttons inside them bind like
#' any other UI: a button() in the footer sets its input on click and
#' the server decides what to do, including calling remove_modal().
#'
#' The dialog is mounted inside #glinty-root, so event delegation
#' reaches it. Only one dialog is shown at a time; showing a second
#' replaces the first.
#'
#' Browser-only: the native backend ignores modal messages.
#'
#' @param session a glinty_session
#' @param ... body elements
#' @param title character heading, or NULL for none
#' @param footer footer elements, typically buttons; wrap several in
#'   row() or div()
#' @param easy_close logical allow dismissing by clicking the
#'   backdrop or pressing Escape
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' show_modal(
#'     session,
#'     p("Download the 'large-v3' model (6.2 GB) from HuggingFace?"),
#'     title = "Download Model?",
#'     footer = row(modal_button("Cancel"), button("confirm", "Download"))
#' )
#' }
#' @export
show_modal <- function(session, ..., title = NULL, footer = NULL,
                       easy_close = TRUE) {
    if (!inherits(session, "glinty_session")) {
        stop("session must be a glinty_session", call. = FALSE)
    }
    body <- list(...)
    session$send(modal_msg(
                           title = title,
                           body = lapply(body, unclass_recursive),
                           footer = if (is.null(footer)) {
                NULL
            } else {
                unclass_recursive(footer)
            },
                           easy_close = isTRUE(easy_close)
        ))
    invisible(NULL)
}

#' Remove the open modal dialog
#'
#' Closing an already-closed dialog is not an error.
#'
#' @param session a glinty_session
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' observe_event(input$confirm, {
#'     remove_modal(session)
#'     download_the_thing()
#' })
#' }
#' @export
remove_modal <- function(session) {
    if (!inherits(session, "glinty_session")) {
        stop("session must be a glinty_session", call. = FALSE)
    }
    session$send(modal_close_msg())
    invisible(NULL)
}

#' Create a button that closes the modal without telling the server
#'
#' The Cancel case: dismissing a dialog is not usually news. For a
#' button the server should hear about, use button() and call
#' remove_modal() from its observer.
#'
#' @param label character button label
#' @return A UI element
#' @examples
#' modal_button("Cancel")
#' @export
modal_button <- function(label = "Cancel") {
    attrs <- list(class = "g-btn g-modal-close", type = "button")
    attrs[["data-g-modal-close"]] <- "1"
    tag("button", text = label, attrs = attrs)
}
