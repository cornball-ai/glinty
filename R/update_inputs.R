#' Update a text input from the server
#'
#' Sends a typed update_input message that the client applies without
#' re-emitting an input event, and syncs the session's server-side
#' input value so state converges without a round trip. The client
#' skips the value patch when the element has focus, so it never
#' stomps live typing.
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param value character new value (NULL leaves it alone)
#' @param label character new label text (NULL leaves it alone)
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' update_text_input(session, "name", value = "Troy")
#' }
#' @export
update_text_input <- function(session, id, value = NULL, label = NULL) {
    send_input_update(session, id, list(value = value, label = label),
                      sync_value = value)
}

#' Update a select input from the server
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param choices character vector of choices; names are display
#'   labels (NULL leaves them alone)
#' @param selected character value to select (NULL leaves it alone,
#'   unless choices are replaced, in which case the first choice is
#'   selected)
#' @param label character new label text
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' update_select_input(session, "engine", choices = c("a", "b"))
#' }
#' @export
update_select_input <- function(session, id, choices = NULL, selected = NULL,
                                label = NULL) {
    choice_list <- NULL
    if (!is.null(choices)) {
        if (is.null(names(choices))) {
            names(choices) <- choices
        }
        if (is.null(selected)) {
            selected <- choices[[1L]]
        }
        choice_list <- lapply(seq_along(choices), function(i) {
            list(value = unname(choices[[i]]), label = names(choices)[[i]])
        })
    }
    send_input_update(session, id,
                      list(choices = choice_list, selected = selected, label = label),
                      sync_value = selected)
}

#' Update a slider input from the server
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param value numeric new value
#' @param min numeric new minimum
#' @param max numeric new maximum
#' @param step numeric new step
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' update_slider_input(session, "n", value = 50)
#' }
#' @export
update_slider_input <- function(session, id, value = NULL, min = NULL,
                                max = NULL, step = NULL) {
    send_input_update(session, id,
                      list(value = value, min = min, max = max, step = step),
                      sync_value = value)
}

#' Update a checkbox input from the server
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param value logical new checked state
#' @param label character new label text
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' update_checkbox_input(session, "save", value = TRUE)
#' }
#' @export
update_checkbox_input <- function(session, id, value = NULL, label = NULL) {
    send_input_update(session, id, list(value = value, label = label),
                      sync_value = value)
}

#' Update a radio button group from the server
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param choices character vector of choices; names are display
#'   labels (NULL leaves them alone)
#' @param selected character value to check (NULL leaves it alone,
#'   unless choices are replaced, in which case the first choice is
#'   checked)
#' @param label character new group label text
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' update_radio_buttons(session, "mode", selected = "careful")
#' }
#' @export
update_radio_buttons <- function(session, id, choices = NULL,
                                 selected = NULL, label = NULL) {
    choice_list <- NULL
    if (!is.null(choices)) {
        if (is.null(names(choices))) {
            names(choices) <- choices
        }
        if (is.null(selected)) {
            selected <- choices[[1L]]
        }
        choice_list <- lapply(seq_along(choices), function(i) {
            list(value = unname(choices[[i]]), label = names(choices)[[i]])
        })
    }
    send_input_update(session, id,
        list(choices = choice_list, selected = selected, label = label),
        sync_value = selected)
}

#' Update a date input from the server
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param value character new date, "YYYY-MM-DD"
#' @param min character new earliest selectable date
#' @param max character new latest selectable date
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' update_date_input(session, "start", value = "2026-01-01")
#' }
#' @export
update_date_input <- function(session, id, value = NULL, min = NULL,
                              max = NULL) {
    if (!is.null(value)) {
        value <- as.character(value)
    }
    send_input_update(session, id,
        list(value = value, min = min, max = max),
        sync_value = value)
}

#' Update a numeric input from the server
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param value numeric new value
#' @param min numeric new minimum
#' @param max numeric new maximum
#' @param step numeric new step
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' update_number_input(session, "k", value = 5)
#' }
#' @export
update_number_input <- function(session, id, value = NULL, min = NULL,
                                max = NULL, step = NULL) {
    send_input_update(session, id,
                      list(value = value, min = min, max = max, step = step),
                      sync_value = value)
}

#' Queue an update_input message and sync server-side state
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param fields named list of update fields; NULLs are dropped
#' @param sync_value if non-NULL, the session's input value is set to
#'   this (invalidating dependents) since the client applies the
#'   update without echoing an input event back
#' @return invisible(NULL)
#' @keywords internal
send_input_update <- function(session, id, fields, sync_value = NULL) {
    fields <- fields[!vapply(fields, is.null, logical(1L))]
    if (length(fields) == 0L) {
        return(invisible(NULL))
    }
    session$send(update_input_msg(id, fields))
    if (!is.null(sync_value)) {
        handle_input(session, id, sync_value)
    }
    invisible(NULL)
}
