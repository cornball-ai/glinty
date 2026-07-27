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
           text_input = html_text_like(x, "text"),
           password_input = html_text_like(x, "password"),
           textarea_input = html_textarea(x),
           number_input = html_number(x),
           select_input = html_select(x),
           checkbox_input = html_checkbox(x),
           radio_buttons = html_radio(x),
           slider_input = html_slider(x),
           date_input = html_text_like(x, "date"),
           file_input = html_file(x),
           button = html_button(x),
           download_button = html_button(x, "g-download"),
           text_output = html_text_output(x),
           verbatim_output = html_el("pre", c(html_slot(x),
                list(class = "g-verbatim-output"))),
           table_output = html_el("div", c(html_slot(x),
                list(class = "g-table-output"))),
           plot_output = html_plot_output(x),
           image_output = html_el("img", c(html_slot(x),
                list(class = "g-image-output", alt = x$alt)), void = TRUE),
           audio_output = html_audio_output(x),
           ui_output = html_el("div", c(html_slot(x),
                                        list(class = "g-ui-output"))),
           tabset = html_tabset(x),
           conditional_panel = html_conditional(x),
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

# --- inputs ---
#
# `emit` becomes a DOM event name here and nowhere else. The component
# says when it wants to report; this is the only place that knows the
# browser calls that "input" or "change".

#' DOM event for an emit intent
#'
#' @param emit character "live" or "settle"
#' @return character DOM event name
#' @keywords internal
emit_event <- function(emit) {
    if (identical(emit, "live")) {
        "input"
    } else {
        "change"
    }
}

#' Wrap a labelled control
#'
#' @param x the component
#' @param control character HTML of the control itself
#' @return character HTML
#' @keywords internal
html_field_group <- function(x, control) {
    label <- ""
    if (!is.null(x$label) && nzchar(x$label)) {
        label <- html_el("label", list("for" = x$id), html_escape(x$label))
    }
    html_el("div", list(class = "g-field"), paste0(label, control))
}

#' Attributes that wire a control to the protocol
#'
#' @param x the component
#' @return named list
#' @keywords internal
html_bind <- function(x) {
    meta <- INPUT_META[[x$component]]
    out <- list(id = x$id)
    out[["data-g-target"]] <- x$id
    out[["data-g-message"]] <- meta$message
    if (!is.null(x$emit)) {
        out[["data-g-event"]] <- emit_event(x$emit)
    }
    out
}

html_text_like <- function(x, type) {
    attrs <- c(html_bind(x),
               list(type = type, class = "g-input",
                    value = if (is.null(x$value)) "" else x$value,
                    placeholder = x$placeholder))
    html_field_group(x, html_el("input", attrs, void = TRUE))
}

html_textarea <- function(x) {
    attrs <- c(html_bind(x),
               list(class = "g-textarea", rows = x$rows, placeholder = x$placeholder))
    html_field_group(x, html_el("textarea", attrs, html_escape(x$value)))
}

html_number <- function(x) {
    attrs <- c(html_bind(x),
               list(type = "number", class = "g-input", value = x$value,
                    min = x$min, max = x$max, step = x$step))
    html_field_group(x, html_el("input", attrs, void = TRUE))
}

html_select <- function(x) {
    opts <- paste(vapply(x$choices, function(ch) {
        sel <- if (identical(ch$value, x$selected)) "selected" else NULL
        html_el("option", list(value = ch$value, selected = sel),
                html_escape(ch$label))
    }, character(1L)), collapse = "")
    attrs <- c(html_bind(x),
               list(class = "g-select",
                    multiple = if (isTRUE(x$multiple)) "multiple" else NULL))
    html_field_group(x, html_el("select", attrs, opts))
}

html_checkbox <- function(x) {
    attrs <- c(html_bind(x),
               list(type = "checkbox", class = "g-checkbox",
                    checked = if (isTRUE(x$value)) "checked" else NULL))
    html_el("div", list(class = "g-check"),
            paste0(html_el("input", attrs, void = TRUE),
                   html_el("label", list("for" = x$id), html_escape(x$label))))
}

html_radio <- function(x) {
    items <- paste(vapply(seq_along(x$choices), function(i) {
        ch <- x$choices[[i]]
        item_id <- paste0(x$id, "_", i)
        attrs <- list(id = item_id, type = "radio", name = x$id,
                      value = ch$value, class = "g-radio",
                      checked = if (identical(ch$value, x$selected)) {
                "checked"
            } else {
                NULL
            })
        attrs[["data-g-target"]] <- x$id
        attrs[["data-g-message"]] <- "input"
        attrs[["data-g-event"]] <- emit_event(x$emit)
        html_el("div", list(class = "g-radio-item"),
                paste0(html_el("input", attrs, void = TRUE),
                       html_el("label", list("for" = item_id), html_escape(ch$label))))
    }, character(1L)), collapse = "")
    html_el("div", list(id = x$id, class = "g-radio-group"),
            paste0(html_el("label", list(class = "g-radio-group-label"),
                           html_escape(x$label)), items))
}

html_slider <- function(x) {
    attrs <- c(html_bind(x),
               list(type = "range", class = "g-slider", min = x$min, max = x$max,
                    value = x$value, step = x$step))
    html_field_group(x, html_el("input", attrs, void = TRUE))
}

html_file <- function(x) {
    # Declares itself like every other input, plus data-g-upload to mark
    # that its value arrives over HTTP rather than the socket. Without
    # the shared attributes it was an input the client had no way to
    # recognise as one.
    attrs <- c(html_bind(x),
               list(type = "file", class = "g-file",
                    multiple = if (isTRUE(x$multiple)) "multiple" else NULL))
    attrs[["data-g-upload"]] <- x$id
    if (!is.null(x$accept)) {
        attrs$accept <- paste(x$accept, collapse = ",")
    }
    html_field_group(x, html_el("input", attrs, void = TRUE))
}

html_button <- function(x, extra_class = NULL) {
    inner <- html_escape(x$label)
    if (!is.null(x$icon)) {
        inner <- paste0(component_to_html(component("icon", name = x$icon)),
                        inner)
    }
    attrs <- c(html_bind(x),
               list(type = "button",
                    class = paste(c("g-btn", paste0("g-btn-", x$variant),
                                    extra_class), collapse = " ")))
    html_el("button", attrs, inner)
}

# --- outputs ---
#
# An output lowers to an empty slot carrying its id and the value kind
# it expects. The client fills it when an `output` message arrives;
# nothing here knows what the value will be.

#' Attributes marking an output slot
#'
#' @param x the component
#' @return named list
#' @keywords internal
html_slot <- function(x) {
    out <- list(id = x$id)
    out[["data-g-output"]] <- x$id
    out[["data-g-kind"]] <- OUTPUT_KINDS[[x$component]]
    out
}

html_text_output <- function(x) {
    cls <- c(normal = "g-output", muted = "g-output g-muted",
             strong = "g-output g-strong")
    html_el("span", c(html_slot(x), list(class = unname(cls[[x$variant]]))))
}

html_plot_output <- function(x) {
    # With no dimensions the element fills its container and the client
    # reports the box back through a `measure` message, which is how
    # render_plot() sizes itself.
    style <- NULL
    if (is.null(x$width) && is.null(x$height)) {
        style <- "width:100%;aspect-ratio:4 / 3"
    }
    html_el("img", c(html_slot(x),
                     list(class = "g-plot-output", alt = x$alt, width = x$width,
                          height = x$height, style = style)),
            void = TRUE)
}

html_audio_output <- function(x) {
    html_el("audio", c(html_slot(x),
                       list(class = "g-audio-output",
                            controls = if (isTRUE(x$controls)) {
                    "controls"
                } else {
                    NULL
                },
                            autoplay = if (isTRUE(x$autoplay)) {
                    "autoplay"
                } else {
                    NULL
                })))
}

# --- composite layout ---

html_tabset <- function(x) {
    selected <- x$selected
    titles <- vapply(x$panels, function(p) p$title, character(1L))
    if (is.null(selected) || !selected %in% titles) {
        selected <- titles[[1L]]
    }
    nav <- paste(vapply(x$panels, function(p) {
        active <- identical(p$title, selected)
        attrs <- list(type = "button",
                      class = paste(c("g-tab-btn", if (active) "g-tab-active"),
                                    collapse = " "))
        attrs[["data-g-tab-panel"]] <- p$title
        attrs[["data-g-target"]] <- x$id
        attrs[["data-g-message"]] <- "input"
        attrs[["data-g-value"]] <- p$title
        html_el("button", attrs, html_escape(p$title))
    }, character(1L)), collapse = "")

    bodies <- paste(vapply(x$panels, function(p) {
        attrs <- list(class = paste(c("g-tab-body",
                    if (!identical(p$title, selected)) {
                        "g-hidden"
                    }),
                                    collapse = " "))
        attrs[["data-g-tab-panel"]] <- p$title
        html_el("div", attrs, children_to_html(p$children))
    }, character(1L)), collapse = "")

    html_el("div", list(id = x$id, class = "g-tabset"),
            paste0(html_el("div", list(class = "g-tab-nav"), nav),
                   html_el("div", list(class = "g-tab-bodies"), bodies)))
}

html_conditional <- function(x) {
    attrs <- list(class = "g-conditional")
    attrs[["data-g-cond"]] <- as.character(
        jsonlite::toJSON(x$condition, auto_unbox = TRUE))
    html_el("div", attrs, children_to_html(x$children))
}
