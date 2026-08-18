# Server-side input seeding.
#
# Protocol 2 learned initial input values from the client: the browser
# harvested the DOM at connect and sent the lot back in `init`. But
# the server built that DOM, so it was asking a question it already
# knew the answer to -- and paying for it with a reload that writes
# the whole form back, and inputs that read NULL until the harvest
# lands.
#
# Under v3 the tree is the source of truth. A session's inputs are
# seeded from it before the server function runs, so reactives see
# defaults on their very first run, and observe_event()'s ignore_init
# means what it says: seeded state is init state, not a change, and
# fires nothing.

#' Seed a session's inputs from its component tree
#'
#' Runs before the server function, so every input the tree declares
#' reads its default rather than NULL from the first flush onward.
#' Inputs the tree does not declare (dynamic UI, custom JS) stay
#' auto-NULL as before.
#'
#' @param session a glinty_session
#' @param ui a component tree
#' @return invisible(NULL)
#' @keywords internal
seed_session_inputs <- function(session, ui) {
    vals <- collect_input_seeds(ui)
    if (anyDuplicated(names(vals)) > 0L) {
        vals <- vals[!duplicated(names(vals))]
    }
    for (id in names(vals)) {
        session$input_env[[id]] <- reactive_val(vals[[id]])
    }
    invisible(NULL)
}

#' Walk a component tree collecting seedable input values
#'
#' Recurses through children and tabset panels; a hidden conditional
#' panel's inputs seed like any other, because hiding is display, not
#' existence.
#'
#' @param x a component or plain list tree
#' @return named list of id -> initial value
#' @keywords internal
collect_input_seeds <- function(x) {
    if (!is.list(x)) {
        return(list())
    }
    out <- list()
    if (!is.null(x$component) && !is.null(x$id)) {
        seed <- input_seed_value(x)
        if (!is.null(seed)) {
            out[[x$id]] <- seed
        }
    }
    for (child in if (is.null(x$children)) list() else x$children) {
        out <- c(out, collect_input_seeds(child))
    }
    for (panel in if (is.null(x$panels)) list() else x$panels) {
        for (child in if (is.null(panel$children)) list() else panel$children) {
            out <- c(out, collect_input_seeds(child))
        }
    }
    out
}

#' The initial value one input component contributes
#'
#' Mirrors what a browser would have harvested from the rendered
#' control, because that is the state the user actually sees:
#' an empty text field is "", an untouched checkbox is FALSE, a
#' single select shows its first choice, a multiple select with
#' nothing chosen is character(0), a slider with no value sits at the
#' midpoint (the HTML default). NULL means this component seeds
#' nothing and the input stays auto-NULL: an empty number field,
#' every button and output.
#'
#' @param x a component (or its unclassed list form)
#' @return an initial value, or NULL
#' @keywords internal
input_seed_value <- function(x) {
    switch(x$component,
           text_input =,
           password_input =,
           textarea_input =,
           date_input = if (is.null(x$value)) "" else x$value,
           number_input = x$value,
           checkbox_input = isTRUE(x$value),
           radio_buttons = x$selected,
           # always plural, character(0) when nothing is checked --
           # the multiple-select rule
           checkbox_group = as.character(unlist(x$selected, use.names = FALSE)),
           slider_input = if (is.null(x$value)) {
            slider_default(x$min, x$max)
        } else {
            x$value
        },
           range_slider = if (is.null(x$value)) {
            c(x$min, x$max)
        } else {
            # the validated tree holds list(lo, hi) (JSON array shape);
            # the server-side value is the numeric pair
            as.numeric(unlist(x$value))
        },
           select_input = select_seed(x),
           tabset = tabset_seed(x),
           NULL
    )
}

#' The HTML default for a slider with no value
#'
#' @param min,max numeric bounds
#' @return numeric midpoint
#' @keywords internal
slider_default <- function(min, max) {
    min + (max - min) / 2
}

#' Initial value of a select input
#'
#' A single select displays its first choice when nothing is
#' selected, so that is its value.
#'
#' A multiple select with nothing selected has an empty selection,
#' which is a character(0) rather than a NULL. The browser harvests
#' `Array.from(el.selectedOptions)` and gets `[]`, so seeding NULL
#' here made the server disagree with the client it is mirroring
#' before a single interaction had happened.
#'
#' @param x a select_input component
#' @return character value, or NULL
#' @keywords internal
select_seed <- function(x) {
    if (isTRUE(x$multiple)) {
        return(as.character(unlist(x$selected, use.names = FALSE)))
    }
    if (!is.null(x$selected)) {
        return(x$selected)
    }
    if (length(x$choices) == 0L) {
        return(NULL)
    }
    x$choices[[1L]]$value
}

#' Initial value of a tabset's selection input
#'
#' Only a tabset with an id has a selection the server tracks. The
#' selected title wins when it names a real panel; otherwise the
#' first panel is shown, which mirrors the lowering.
#'
#' @param x a tabset component
#' @return character panel title, or NULL
#' @keywords internal
tabset_seed <- function(x) {
    if (is.null(x$id) || length(x$panels) == 0L) {
        return(NULL)
    }
    titles <- vapply(x$panels, function(p) p$title, character(1L))
    if (!is.null(x$selected) && x$selected %in% titles) {
        return(x$selected)
    }
    titles[[1L]]
}
