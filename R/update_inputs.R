#' Update a text input from the server
#'
#' Sends a typed input_update message that the client applies without
#' re-emitting an input event, and syncs the session's server-side
#' input value so state converges without a round trip. The client
#' skips the value patch when the element has focus, so it never
#' stomps live typing.
#'
#' `focus = TRUE` moves the keyboard focus to this field on arrival.
#' It is a one-shot verb, not state: focus lives in no tree, so the
#' message says "focus it now" and is spent. It applies even when some
#' other field is focused -- moving the caret is not the hazard the
#' never-stomp guard exists for (rewriting a draft is), and the app
#' asking to move the user's attention is the point. The case this
#' exists for: a composer that should be ready to type into after the
#' server swaps the layout, where the rebuilt DOM dropped focus with
#' the old tree.
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param value character new value (NULL leaves it alone)
#' @param label character new label text (NULL leaves it alone)
#' @param focus logical move keyboard focus to this field (FALSE sends
#'   nothing; there is no "unfocus" verb)
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' update_text_input(session, "name", value = "Troy")
#' update_text_input(session, "draft", focus = TRUE)
#' }
#' @export
update_text_input <- function(session, id, value = NULL, label = NULL,
                              focus = FALSE) {
    send_input_update(session, id,
                      list(value = value, label = label, focus = if (isTRUE(focus)) TRUE),
                      sync_value = value)
}

#' Update a select input from the server
#'
#' @param session a glinty_session
#' @param id character input ID
#' @param choices character vector of choices; names are display
#'   labels (NULL leaves them alone)
#' @param selected character value(s) to select (NULL leaves it
#'   alone, unless choices are replaced, in which case the first
#'   choice is selected). More than one value means a multiple
#'   select, and is sent as an array
#' @param multiple logical whether this control is a multiple select.
#'   Only needed to send one or zero selections to one: the wire form
#'   of `selected` is an array at every length there, and a length-1
#'   vector cannot say on its own which it meant
#' @param label character new label text
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' update_select_input(session, "engine", choices = c("a", "b"))
#' update_select_input(session, "tags", selected = c("a", "c"))
#' update_select_input(session, "tags", selected = "a", multiple = TRUE)
#' }
#' @export
update_select_input <- function(session, id, choices = NULL, selected = NULL,
                                label = NULL, multiple = NULL) {
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
    # `selected` is an array at every length for a multiple select --
    # the same rule the component schema keeps, and for the same
    # reason: a one-element selection that arrives as a bare string
    # makes a client parse a list sometimes and a string other times.
    # Two or more values say so by themselves; one or none cannot, so
    # `multiple` is how a caller says it.
    #
    # NULL stays NULL throughout: it means "leave the selection
    # alone", and turning it into an empty array here would make
    # update_select_input(label = ) clear a selection it was never
    # asked about. Clearing one is character(0), which says so.
    wire <- selected
    if (!is.null(selected) && (isTRUE(multiple) || length(selected) > 1L)) {
        wire <- as.list(as.character(selected))
    }
    send_input_update(session, id,
                      list(choices = choice_list, selected = wire, label = label),
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
    send_input_update(session, id, list(value = value, min = min, max = max),
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

#' Queue an input_update message and sync server-side state
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
    session$send(input_update_msg(id, fields))
    if (!is.null(sync_value)) {
        handle_input(session, id, sync_value)
    }
    invisible(NULL)
}
