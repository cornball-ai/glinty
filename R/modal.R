#' Show a modal dialog
#'
#' The body and footer are ordinary components, so inputs and buttons
#' inside them bind like any other UI: a button() in the footer sets
#' its input on press and the server decides what to do, including
#' calling remove_modal().
#'
#' Only one dialog shows at a time; a second replaces the first.
#'
#' @param session a glinty_session
#' @param ... body components
#' @param title character heading, or NULL
#' @param footer footer components; wrap several in row()
#' @param easy_close logical allow dismissing by backdrop or Escape
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' show_modal(
#'     session,
#'     text("Download the model (6.2 GB)?"),
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
    body <- check_children(list(...), "show_modal")
    session$send(modal_msg(
                           title = title,
                           body = lapply(body, unclass_recursive),
                           footer = if (is.null(footer)) NULL else unclass_recursive(footer),
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
#' observe_event(input$confirm, function() remove_modal(session))
#' }
#' @export
remove_modal <- function(session) {
    if (!inherits(session, "glinty_session")) {
        stop("session must be a glinty_session", call. = FALSE)
    }
    session$send(modal_close_msg())
    invisible(NULL)
}

#' The one reserved component id
#'
#' A button carrying it closes the open dialog locally and reports
#' nothing. Reserved rather than app-chosen because ids opening with
#' ".." are refused on the input path, so no app can collide with it.
#'
#' Both lowerings read this: the browser marks the button with
#' data-g-modal-close, Flutter checks the id directly. A magic string
#' either side does not know is a button that renders and does
#' nothing.
#'
#' @keywords internal
MODAL_CLOSE_ID <- "..modal_close"

#' Create a button that closes the modal without telling the server
#'
#' The Cancel case: dismissing a dialog is not usually news. For a
#' button the server should hear about, use button() and call
#' remove_modal() from its observer.
#'
#' @param label character button label
#' @return A UI component
#' @examples
#' modal_button("Cancel")
#' @export
modal_button <- function(label = "Cancel") {
    component("button", id = MODAL_CLOSE_ID, label = label, variant = "ghost")
}
