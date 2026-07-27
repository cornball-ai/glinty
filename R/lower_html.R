# Component -> DOM lowering for the browser frontend.
#
# One of two lowerings that must agree; the other is component -> flitR
# ops in native_scene.R. Neither is the canonical form: the component
# tree is. If something here needs a field that only makes sense as
# HTML, that is a signal the component is DOM-shaped and the schema is
# wrong -- not a reason to add the field.

#' Lower a component tree to HTML
#'
#' Used for the browser's server-rendered first paint. The same tree
#' also travels to the client as JSON, which builds equivalent DOM;
#' the two must produce the same result, which is what `ui_revision`
#' hydration checks at runtime and the shared fixtures check in tests.
#'
#' @param x a glinty_component
#' @return character HTML
#' @keywords internal
component_to_html <- function(x) {
    if (is.null(x)) {
        return("")
    }
    if (!is_component(x)) {
        stop("component_to_html() expects a component, got ",
             paste(class(x), collapse = "/"), call. = FALSE)
    }

    switch(x$component,
           text = html_text(x),
           heading = html_heading(x),
           link = html_link(x),
           icon = html_icon(x),
           divider = html_divider(x),
           spacer = html_spacer(x),
           page = html_container(x, "div", "g-page"),
           row = html_layout(x, "g-layout-row"),
           column = html_layout(x, "g-layout-col"),
           panel = html_panel(x),
           raw_html = x$html,
           html_unsupported(x$component)
    )
}

#' Lower a list of children
#'
#' @param children list of components
#' @return character HTML
#' @keywords internal
children_to_html <- function(children) {
    if (length(children) == 0L) {
        return("")
    }
    paste(vapply(children, component_to_html, character(1L)), collapse = "")
}

#' Build an HTML element
#'
#' @param tag_name character element name
#' @param attrs named list of attributes; NULLs are dropped
#' @param inner character inner HTML, already escaped or built
#' @param void logical self-closing element
#' @return character HTML
#' @keywords internal
html_el <- function(tag_name, attrs = list(), inner = "", void = FALSE) {
    attrs <- attrs[!vapply(attrs, is.null, logical(1L))]
    parts <- ""
    if (length(attrs) > 0L) {
        parts <- paste0(" ", paste(
                                   paste0(names(attrs), "=\"",
                    vapply(attrs, function(v) html_escape(as.character(v)),
                           character(1L)), "\""),
                                   collapse = " "))
    }
    if (void) {
        return(paste0("<", tag_name, parts, ">"))
    }
    paste0("<", tag_name, parts, ">", inner, "</", tag_name, ">")
}

#' Placeholder for a component this frontend cannot render
#'
#' Visible and named, never silent. A component that quietly vanishes
#' is the failure mode this whole redesign exists to avoid.
#'
#' @param name character component name
#' @return character HTML
#' @keywords internal
html_unsupported <- function(name) {
    html_el("div", list(class = "g-unsupported", "data-g-component" = name),
            paste0("[unsupported component: ", html_escape(name), "]"))
}

# --- static content ---

html_text <- function(x) {
    cls <- c(normal = "g-text", muted = "g-text g-muted",
             strong = "g-text g-strong", heading = "g-text g-text-heading")
    html_el("span", list(class = unname(cls[[x$variant]]), id = x$id),
            html_escape(x$value))
}

html_heading <- function(x) {
    html_el(paste0("h", x$level), list(id = x$id), html_escape(x$value))
}

html_link <- function(x) {
    attrs <- list(href = x$href, class = "g-link")
    if (isTRUE(x$external)) {
        attrs$target <- "_blank"
        attrs$rel <- "noopener noreferrer"
    }
    html_el("a", attrs, html_escape(x$value))
}

html_icon <- function(x) {
    # The name is a token, not artwork: the frontend owns the glyph.
    # Unknown names render an empty box rather than nothing, so a typo
    # is visible.
    html_el("span", list(class = paste0("g-icon g-icon-", x$name),
                         "data-g-icon" = x$name,
                         style = paste0("width:", x$size, "px;height:", x$size, "px"),
                         "aria-hidden" = "true"))
}

html_divider <- function(x) {
    if (identical(x$variant, "labelled") && !is.null(x$label)) {
        return(html_el("div", list(class = "g-divider g-divider-labelled"),
                       html_el("span", list(class = "g-divider-label"),
                               html_escape(x$label))))
    }
    html_el("hr", list(class = "g-divider"), void = TRUE)
}

html_spacer <- function(x) {
    html_el("div", list(class = "g-spacer",
                        "data-g-size" = x$size,
                        style = paste0("height:calc(var(--g-space) * ", x$size, ")")))
}

# --- layout ---

html_container <- function(x, tag_name, cls) {
    html_el(tag_name, list(class = cls, id = x$id),
            children_to_html(x$children))
}

html_layout <- function(x, cls) {
    style <- NULL
    if (!is.null(x$gap)) {
        style <- paste0("gap:", x$gap, "px")
    }
    if (!is.null(x$align)) {
        align <- switch(x$align, start = "flex-start", center = "center",
                        end = "flex-end")
        style <- paste(c(style, paste0("align-items:", align)), collapse = ";")
    }
    html_el("div", list(class = cls, id = x$id, style = style),
            children_to_html(x$children))
}

html_panel <- function(x) {
    inner <- children_to_html(x$children)
    if (!is.null(x$title)) {
        inner <- paste0(html_el("div", list(class = "g-panel-title"),
                                html_escape(x$title)), inner)
    }
    html_el("div", list(class = paste0("g-panel g-panel-", x$variant),
                        id = x$id), inner)
}
