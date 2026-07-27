# Component -> flitR op lowering for the native frontend.
#
# The second of two lowerings. Its job in stage 1 is not feature
# parity -- flitR is feature-frozen -- but to be a second opinion on
# whether the component vocabulary is genuinely frontend-neutral.
#
# Where this lowering has to reach for something the HTML one gets for
# free, that is the interesting signal. Notably: flitR computes layout
# in R and emits absolutely-positioned draw ops, so anything the
# schema expresses as a CSS-ish hint has to survive being turned into
# arithmetic. `gap` is a number for exactly that reason.

NATIVE_TEXT_SIZES <- c(normal = 14, muted = 14, strong = 14, heading = 16)
NATIVE_HEADING_LEVELS <- c(24, 20, 17, 15)
NATIVE_COLORS <- c(normal = "#111111", muted = "#666666", strong = "#000000",
                   heading = "#111111")

#' Lower a component tree to flitR ops
#'
#' @param x a glinty_component
#' @param unsupported collector env with a `$names` character vector
#' @return a flitR item, or NULL to contribute nothing
#' @keywords internal
component_to_flitr <- function(x, unsupported) {
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
           page = flitr_stack(x, unsupported, gap = 10),
           column = flitr_stack(x, unsupported,
                                gap = if (is.null(x$gap)) 8 else x$gap),
           row = flitr_row(x, unsupported),
           panel = flitr_panel(x, unsupported),
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
#' @param unsupported collector env
#' @return list of flitR items
#' @keywords internal
children_to_flitr <- function(children, unsupported) {
    out <- list()
    for (child in children) {
        item <- component_to_flitr(child, unsupported)
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

flitr_stack <- function(x, unsupported, gap) {
    items <- children_to_flitr(x$children, unsupported)
    if (length(items) == 0L) {
        return(NULL)
    }
    do.call(flitR::column, c(items, list(gap = gap)))
}

flitr_row <- function(x, unsupported) {
    items <- children_to_flitr(x$children, unsupported)
    if (length(items) == 0L) {
        return(NULL)
    }
    do.call(flitR::row, c(items, list(gap = if (is.null(x$gap)) 12 else x$gap)))
}

flitr_panel <- function(x, unsupported) {
    items <- children_to_flitr(x$children, unsupported)
    if (!is.null(x$title)) {
        items <- c(list(flitR::text(0, 0, x$title, size = 13,
                                    color = "#666666")), items)
    }
    if (length(items) == 0L) {
        return(NULL)
    }
    do.call(flitR::column, c(items, list(gap = 6)))
}
