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
component_to_flitr <- function(x, session, values, unsupported) {
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
           page = flitr_stack(x, session, values, unsupported, gap = 10),
           column = flitr_stack(x, session, unsupported,
                                gap = if (is.null(x$gap)) 8 else x$gap),
           row = flitr_row(x, session, values, unsupported),
           panel = flitr_panel(x, session, values, unsupported),
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
           text_output =,
           verbatim_output =,
           table_output =,
           plot_output =,
           image_output =,
           audio_output =,
           ui_output = flitr_output(x, values, unsupported),
           tabset = flitr_tabset(x, session, values, unsupported),
           conditional_panel = flitr_conditional(x, session, values, unsupported),
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
children_to_flitr <- function(children, session, values, unsupported) {
    out <- list()
    for (child in children) {
        item <- component_to_flitr(child, session, values, unsupported)
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

flitr_stack <- function(x, session, values, unsupported, gap) {
    items <- children_to_flitr(x$children, session, values, unsupported)
    if (length(items) == 0L) {
        return(NULL)
    }
    do.call(flitR::column, c(items, list(gap = gap)))
}

flitr_row <- function(x, session, values, unsupported) {
    items <- children_to_flitr(x$children, session, values, unsupported)
    if (length(items) == 0L) {
        return(NULL)
    }
    do.call(flitR::row, c(items, list(gap = if (is.null(x$gap)) 12 else x$gap)))
}

flitr_panel <- function(x, session, values, unsupported) {
    items <- children_to_flitr(x$children, session, values, unsupported)
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

# --- outputs ---
#
# An output slot draws whatever value has arrived for its id. flitR has
# no notion of an empty element waiting to be filled, so a slot with no
# value yet draws its placeholder rather than nothing -- otherwise the
# scene silently loses height and everything below it shifts when the
# first value lands.

#' Lower an output component to a flitR item
#'
#' @param x a glinty_component
#' @param values env of output id -> latest value
#' @param unsupported collector env
#' @return a flitR item, or NULL
#' @keywords internal
flitr_output <- function(x, values, unsupported) {
    val <- values[[x$id]]

    switch(x$component,
           text_output = flitR::text(0, 0, native_text(val),
                                     size = NATIVE_TEXT_SIZES[[x$variant]],
                                     color = NATIVE_COLORS[[x$variant]]),
           verbatim_output = flitR::text(0, 0, native_text(val), size = 13),
           table_output = flitr_table(val),
           plot_output =,
           image_output = flitr_image(x, val),
           {
        # audio_output and ui_output. Audio needs a player flitR
        # does not have; ui_output needs the tree that arrives at
        # runtime, which stage 2 delivers. Named, not approximated.
        unsupported$names <- c(unsupported$names, x$component)
        NULL
    }
    )
}

#' An output value as displayable text
#'
#' @param val the value, possibly NULL
#' @return character
#' @keywords internal
native_text <- function(val) {
    if (is.null(val)) {
        return("")
    }
    paste(as.character(val), collapse = " ")
}

flitr_table <- function(val) {
    if (is.null(val) || is.null(val$header)) {
        return(flitR::text(0, 0, "", size = 13))
    }
    rows <- lapply(val$rows, function(r) paste(unlist(r), collapse = "   "))
    lines <- c(paste(unlist(val$header), collapse = "   "), unlist(rows))
    items <- lapply(lines, function(l) flitR::text(0, 0, l, size = 12))
    do.call(flitR::column, c(items, list(gap = 2)))
}

flitr_image <- function(x, val) {
    if (is.null(x$width)) {
        w <- 480
    } else {
        w <- x$width
    }
    if (is.null(x$height)) {
        h <- 360
    } else {
        h <- x$height
    }
    if (is.null(val) || is.null(val$src)) {
        # Hold the space, so the scene does not reflow on first render.
        return(flitR::rect(0, 0, w, h, "#F4F4F4"))
    }
    if (!is.null(val$width)) {
        w <- val$width
    }
    if (!is.null(val$height)) {
        h <- val$height
    }
    flitR::image(0, 0, w = w, h = h, src = val$src)
}

# --- composite layout ---

flitr_tabset <- function(x, session, values, unsupported) {
    titles <- vapply(x$panels, function(p) p$title, character(1L))
    selected <- isolate(session$input[[x$id]]())
    if (!is.character(selected) || length(selected) != 1L ||
        !selected %in% titles) {
        selected <- if (!is.null(x$selected) && x$selected %in% titles) {
            x$selected
        } else {
            titles[[1L]]
        }
    }

    strip <- flitR::tabs(x$id, 0, 0, titles, selected = selected,
                         on_select = function(label) {
        handle_input(session, x$id, label)
    })

    # Only the selected panel is emitted: an unselected tab is not
    # hidden in immediate mode, it is simply not drawn this frame.
    body <- Filter(function(p) identical(p$title, selected), x$panels)
    items <- list(strip)
    if (length(body) > 0L) {
        kids <- children_to_flitr(body[[1L]]$children, session, values,
                                  unsupported)
        if (length(kids) > 0L) {
            items <- c(items, list(do.call(flitR::column,
                        c(kids, list(gap = 8)))))
        }
    }
    do.call(flitR::column, c(items, list(gap = 10)))
}

flitr_conditional <- function(x, session, values, unsupported) {
    if (!eval_condition(x$condition, session)) {
        return(NULL)
    }
    items <- children_to_flitr(x$children, session, values, unsupported)
    if (length(items) == 0L) {
        return(NULL)
    }
    do.call(flitR::column, c(items, list(gap = 4)))
}
