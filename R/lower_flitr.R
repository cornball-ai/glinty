# Component -> flitR op lowering for the native frontend.
#
# The second of two lowerings. Its job in stage 1 is not feature
# parity -- flitR is feature-frozen -- but to be a second opinion on
# whether the component vocabulary is genuinely frontend-neutral.
#
# READ THIS BEFORE TREATING IT AS EVIDENCE: flitR is a **falsifier,
# not a validator**. Where it cannot lower something sensibly, the
# component is probably DOM-shaped -- that is a real finding, and it
# is how `gap` ended up a number and `spacer` ended up in theme units
# rather than CSS. But flitR *succeeding* proves very little about
# Flutter, because flitR is more primitive than the DOM in the
# opposite direction: absolutely-positioned draw ops with layout
# computed in R, versus a framework that owns layout, retains widget
# state, and has its own focus and text models.
#
# So: flitR disagreeing is a signal. flitR agreeing is not a
# clearance. The Flutter mapping in PROTOCOL.md is the check that
# actually points at the target; this one just catches browser bias.
#
# Corollary, and the easier mistake: nothing here should be allowed to
# shape the schema. flitR has no live/settle distinction, so it cannot
# honour `emit` -- that is flitR's limitation, and `emit` stays
# because Flutter's onChanged/onEditingComplete needs it.

NATIVE_TEXT_SIZES <- c(normal = 14, muted = 14, strong = 14, heading = 16)
NATIVE_HEADING_LEVELS <- c(24, 20, 17, 15)
NATIVE_COLORS <- c(normal = "#111111", muted = "#666666", strong = "#000000",
                   heading = "#111111")

#' Lower a component tree to flitR ops
#'
#' @param x a glinty_component
#' @param session the native session
#' @param unsupported collector env with a `$names` character vector
#' @return a flitR item, or NULL to contribute nothing
#' @keywords internal
component_to_flitr <- function(x, session, unsupported) {
    if (is.null(x)) {
        return(NULL)
    }
    if (!is_component(x)) {
        stop("component_to_flitr() expects a component, got ",
             paste(class(x), collapse = "/"), call. = FALSE)
    }

    switch(x$component,
           text = flitr_text(x),
           heading = flitR::text(0, 0, x$value,
                                 size = NATIVE_HEADING_LEVELS[[x$level]]),
           link = flitR::text(0, 0, x$value, size = 14, color = "#2456D6"),
           divider = flitr_divider(x),
           spacer = flitr_spacer(x),
           page = flitr_stack(x, session, unsupported, gap = 10),
           column = flitr_stack(x, session, unsupported,
                                gap = if (is.null(x$gap)) 8 else x$gap),
           row = flitr_row(x, session, unsupported),
           panel = flitr_panel(x, session, unsupported),
           text_input =,
           password_input =,
           textarea_input =,
           number_input =,
           select_input =,
           checkbox_input =,
           slider_input =,
           radio_buttons =,
           date_input =,
           file_input =,
           button =,
           download_button = flitr_input(x, session, unsupported),
           {
        # icon and raw_html land here. An icon needs artwork flitR
        # has no library for, and raw markup has no draw-op
        # translation at all. Both are named refusals rather than
        # approximations.
        unsupported$names <- c(unsupported$names, x$component)
        NULL
    }
    )
}

#' Lower a list of children, dropping the ones that contribute nothing
#'
#' @param children list of components
#' @param session the native session
#' @param unsupported collector env
#' @return list of flitR items
#' @keywords internal
children_to_flitr <- function(children, session, unsupported) {
    out <- list()
    for (child in children) {
        item <- component_to_flitr(child, session, unsupported)
        if (!is.null(item)) {
            out <- c(out, list(item))
        }
    }
    out
}

flitr_text <- function(x) {
    flitR::text(0, 0, x$value, size = NATIVE_TEXT_SIZES[[x$variant]],
                color = NATIVE_COLORS[[x$variant]])
}

flitr_divider <- function(x) {
    # A labelled divider is drawn as its label. flitR has no rule with
    # text through it, and inventing one would be approximating.
    if (identical(x$variant, "labelled") && !is.null(x$label)) {
        return(flitR::text(0, 0, x$label, size = 11, color = "#999999"))
    }
    flitR::rect(0, 0, 240, 1, "#DDDDDD")
}

flitr_spacer <- function(x) {
    # The browser reads size in theme spacing units via CSS calc();
    # here it has to become pixels, because flitR positions in pixels.
    # Same field, two lowerings, no leakage either way.
    flitR::rect(0, 0, 1, x$size * 8, "#00000000")
}

flitr_stack <- function(x, session, unsupported, gap) {
    items <- children_to_flitr(x$children, session, unsupported)
    if (length(items) == 0L) {
        return(NULL)
    }
    do.call(flitR::column, c(items, list(gap = gap)))
}

flitr_row <- function(x, session, unsupported) {
    items <- children_to_flitr(x$children, session, unsupported)
    if (length(items) == 0L) {
        return(NULL)
    }
    do.call(flitR::row, c(items, list(gap = if (is.null(x$gap)) 12 else x$gap)))
}

flitr_panel <- function(x, session, unsupported) {
    items <- children_to_flitr(x$children, session, unsupported)
    if (!is.null(x$title)) {
        items <- c(list(flitR::text(0, 0, x$title, size = 13,
                                    color = "#666666")), items)
    }
    if (length(items) == 0L) {
        return(NULL)
    }
    do.call(flitR::column, c(items, list(gap = 6)))
}

# --- inputs ---
#
# flitR's widgets take an on_change callback rather than an event
# name, which is the point: `emit` is intent, and each frontend spends
# it differently. flitR has no notion of live-versus-settle at all --
# its input reports on every keystroke -- so "settle" is honoured by
# the browser and simply unavailable here. That is a real divergence,
# recorded rather than papered over.

#' Lower an input component to a flitR widget
#'
#' @param x a glinty_component
#' @param session the native session
#' @param unsupported collector env
#' @return a flitR widget, or NULL
#' @keywords internal
flitr_input <- function(x, session, unsupported) {
    id <- x$id
    report <- function(v) handle_input(session, id, v)
    cur <- isolate(session$input[[id]]())

    switch(x$component,
           text_input = flitR::input(id, 0, 0, w = 260, h = 32,
                                     value = as.character(cur %||% x$value),
                                     placeholder = x$placeholder %||% "",
                                     on_change = report),
           password_input = flitR::input(id, 0, 0, w = 260, h = 32,
            value = as.character(cur %||% ""),
            placeholder = x$placeholder %||% "",
            mask = TRUE, on_change = report),
           textarea_input = flitR::textarea(id, 0, 0, w = 300, rows = x$rows,
            value = as.character(cur %||% x$value),
            on_change = report),
           number_input = flitR::number(id, 0, 0, w = 120, h = 32,
                                        value = cur %||% x$value,
                                        on_change = report),
           select_input = flitr_select(x, cur, report),
           checkbox_input = flitR::checkbox(id, 0, 0, size = 22,
            value = isTRUE(cur %||% x$value),
            on_change = report),
           slider_input = flitR::slider(id, 0, 0, w = 260, h = 24,
                                        value = cur %||% x$value %||% x$min,
                                        min = x$min, max = x$max,
                                        on_change = report),
           button = flitR::button(id, 0, 0, w = 24 + 9 * nchar(x$label), h = 34,
                                  label = x$label,
                                  on_click = function() handle_click(session, id)),
           {
        # radio_buttons, date_input, file_input and download_button.
        # Each needs a widget flitR does not have, and inventing one
        # would be a feature, which is what the freeze forbids.
        unsupported$names <- c(unsupported$names, x$component)
        NULL
    }
    )
}

flitr_select <- function(x, cur, report) {
    values <- vapply(x$choices, function(ch) ch$value, character(1L))
    labels <- vapply(x$choices, function(ch) ch$label, character(1L))
    choices <- values
    names(choices) <- labels
    flitR::select(x$id, 0, 0, w = 200, h = 32,
                  value = cur %||% x$selected %||% values[[1L]],
                  choices = choices, on_change = report)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
