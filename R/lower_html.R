# Component -> DOM lowering for the browser frontend.
#
# One of two lowerings that must agree; the other is the Flutter
# renderer in dart/glinty_flutter. Neither is the canonical form: the
# component tree is. If something here needs a field that only makes
# sense as HTML, that is a signal the component is DOM-shaped and the
# schema is wrong -- not a reason to add the field.

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
           image = html_image(x),
           collapse = html_collapse(x),
           divider = html_divider(x),
           spacer = html_spacer(x),
           page = html_container(x, "div",
            if (identical(x$width, "full")) {
                "g-page g-page-full"
            } else {
                "g-page"
            }),
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
           video_output = html_video_output(x),
           html_output = html_el("div", c(html_slot(x),
                list(class = "g-html-output"))),
           ui_output = html_el("div", c(html_slot(x),
                                        list(class = "g-ui-output"))),
           tabset = html_tabset(x),
           conditional_panel = html_conditional(x),
           shortcut = html_shortcut(x),
           raw_html = x$html,
           html_unsupported(x$component)
    )
}

#' A key binding, lowered to a hidden marker the client binds from
#'
#' There is no keyboard element in HTML, so the binding rides in the
#' DOM as data and one delegated listener reads it. That keeps the
#' bindings in the tree rather than in a registry beside it: a rebuilt
#' UI has exactly the shortcuts its new tree declares, with none left
#' over from the old one.
#'
#' @param x the component
#' @return character HTML
#' @keywords internal
html_shortcut <- function(x) {
    flag <- function(v) if (isTRUE(v)) "1" else NULL
    html_el("span", list(hidden = "hidden", class = "g-shortcut",
                         "data-g-target" = x$id, "data-g-message" = "event",
                         "data-g-key" = x$key, "data-g-value" = x$value,
                         "data-g-ctrl" = flag(x$ctrl),
                         "data-g-shift" = flag(x$shift),
                         "data-g-alt" = flag(x$alt),
                         "data-g-typing" = flag(x$typing),
                         "data-g-hold" = flag(x$hold)))
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
             strong = "g-text g-strong", heading = "g-text g-text-heading",
             mono = "g-text g-mono", small = "g-text g-small")
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
    inner <- if (length(x$children) > 0L) {
        children_to_html(x$children)
    } else {
        html_escape(x$value)
    }
    html_el("a", attrs, inner)
}

#' Inline style for a container's share of its parent
#'
#' `grow` and `width` are numbers on both sides of the wire; this is
#' the only place they become CSS. flex-grow with a zero basis is what
#' makes "fill the rest" behave the same whatever the content is,
#' which is the whole reason the field exists.
#'
#' @param x the component
#' @return character style fragment, or NULL
#' @keywords internal
html_flex_style <- function(x) {
    if (!html_is_sized(x)) {
        return(NULL)
    }
    # All four, always. Custom properties inherit, so a sized element
    # that set only some of them picked the rest up from a sized
    # ancestor: a fixed-width child inside a grown parent inherited
    # --g-grow and grew, and a grown child inside a fixed parent
    # inherited --g-width and did not. Setting every one makes each
    # element say its whole size and inherit none of it.
    if (!is.null(x$grow) && x$grow > 0L) {
        grow <- x$grow
    } else {
        grow <- 0L
    }
    if (!is.null(x$width)) {
        basis <- paste0(x$width, "px")
        width <- basis
        shrink <- 0L
    } else {
        if (grow > 0L) {
            basis <- "0"
        } else {
            basis <- "auto"
        }
        width <- "auto"
        shrink <- 1L
    }
    paste0("--g-grow:", grow, ";--g-shrink:", shrink, ";--g-basis:",
           basis, ";--g-width:", width)
}

#' Does this component carry sizing?
#'
#' @param x the component
#' @return logical
#' @keywords internal
html_is_sized <- function(x) {
    (!is.null(x$grow) && x$grow > 0L) || !is.null(x$width)
}

html_image <- function(x) {
    html_el("img", list(class = "g-image", src = x$src, alt = x$alt,
                        width = x$width, height = x$height), void = TRUE)
}

html_collapse <- function(x) {
    summary <- html_el("summary", list(class = "g-collapse-title"),
                       html_escape(x$title))
    html_el("details",
            list(class = "g-collapse", id = x$id,
                 open = if (isTRUE(x$open)) "open" else NULL),
            paste0(summary, html_el("div", list(class = "g-collapse-body"),
                                    children_to_html(x$children))))
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
                        end = "flex-end", stretch = "stretch")
        style <- paste(c(style, paste0("align-items:", align)), collapse = ";")
    }
    style <- paste(c(style, html_flex_style(x)), collapse = ";")
    html_el("div", list(class = paste(c(cls, if (html_is_sized(x)) "g-sized",
                    if (isTRUE(x$scroll)) "g-scroll"),
                                      collapse = " "),
                        id = x$id,
                        style = if (nzchar(style)) style else NULL),
            children_to_html(x$children))
}

html_panel <- function(x) {
    inner <- children_to_html(x$children)
    if (!is.null(x$title)) {
        inner <- paste0(html_el("div", list(class = "g-panel-title"),
                                html_escape(x$title)), inner)
    }
    html_el("div", list(class = paste(c(paste0("g-panel g-panel-", x$variant),
                    if (html_is_sized(x)) "g-sized",
                    if (isTRUE(x$fill)) "g-fill"),
                                      collapse = " "),
                        id = x$id, style = html_flex_style(x)), inner)
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
    # A component's `id` is which server handler hears it, not which
    # element it is, and for an event those are never the same thing:
    # nothing makes a button id unique. A list of rows shares one
    # deliberately -- that is what `value` is for -- and a form with
    # Save at the top and the bottom shares one without meaning
    # anything by it. Either way, emitting it as a DOM id duplicates
    # it.
    #
    # An input is different: its id names one value in one store, so
    # it is an identity and keeps the attribute. data-g-target carries
    # the routing name in both cases, which is what the click
    # delegation reads and what elementFor() falls back to.
    if (identical(meta$message, "event")) {
        out <- list()
    } else {
        out <- list(id = x$id)
    }
    out[["data-g-target"]] <- x$id
    out[["data-g-message"]] <- meta$message
    if (!is.null(x$emit)) {
        out[["data-g-event"]] <- emit_event(x$emit)
    }
    # A button's value rides along on the event it emits, which is
    # what lets one handler serve a list of rows. The tabset lowering
    # has always used this attribute for the same purpose; a button
    # can now say it too.
    if (!is.null(x$value) && identical(meta$message, "event")) {
        out[["data-g-value"]] <- x$value
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
    # A multiple select carries a list of selections, so membership
    # rather than equality. identical() against a list is always
    # FALSE, which rendered every option unselected however many the
    # app had chosen.
    chosen <- as.character(unlist(x$selected, use.names = FALSE))
    opts <- paste(vapply(x$choices, function(ch) {
        sel <- if (ch$value %in% chosen) "selected" else NULL
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
    # Tick marks, the native way: a datalist of step positions makes
    # the browser draw ticks on the track, the twin of the division
    # dots Flutter derives from the same step. Capped because a
    # 500-tick track is noise, not a scale.
    ticks <- ""
    if (!is.null(x$step) && x$step > 0) {
        n <- (x$max - x$min) / x$step
        if (is.finite(n) && n >= 1 && n <= 24) {
            tick_id <- paste0(x$id, "-ticks")
            attrs$list <- tick_id
            marks <- vapply(0L:as.integer(round(n)), function(i) {
                html_el("option",
                        list(value = num_label(x$min + i * x$step)),
                        inner = "")
            }, character(1L))
            ticks <- html_el("datalist", list(id = tick_id),
                             paste0(marks, collapse = ""))
        }
    }
    # A slider without numbers answers "roughly how far along?" and
    # nothing else. Min and max name the scale, the readout names the
    # value -- the client keeps the readout tracking the thumb.
    shown <- if (is.null(x$value)) x$min else x$value
    row <- html_el("div", list(class = "g-slider-row"),
        paste0(
            html_el("span", list(class = "g-slider-min"),
                    num_label(x$min)),
            html_el("input", attrs, void = TRUE),
            ticks,
            html_el("span", list(class = "g-slider-max"),
                    num_label(x$max)),
            html_el("output", list(class = "g-slider-value", "for" = x$id),
                    num_label(shown))
        ))
    html_field_group(x, row)
}

# The shortest plain rendering of a number, matching what the browser
# client prints for the same JSON value (String() of the parsed
# number): no scientific notation, no trailing zeros.
num_label <- function(v) {
    format(v, scientific = FALSE, trim = TRUE, drop0trailing = TRUE)
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
    # modal_button() dismisses the dialog and tells nobody, so it
    # carries the close mark instead of an event binding. Both halves
    # matter: without the mark the client's delegation never fires
    # (the button renders and does nothing), and with the binding
    # still attached a Cancel would also report, which is the one
    # thing modal_button() exists not to do.
    closes <- identical(x$id, MODAL_CLOSE_ID)
    attrs <- c(if (closes) list() else html_bind(x),
               list(type = "button",
                    class = paste(c("g-btn", paste0("g-btn-", x$variant),
                                    extra_class), collapse = " ")))
    if (closes) {
        attrs[["data-g-modal-close"]] <- "1"
    }
    if (identical(x$component, "download_button")) {
        # what the client's click delegation keys on: a press asks
        # for a download ticket instead of emitting an event frame
        attrs[["data-g-download"]] <- x$id
    }
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
             strong = "g-output g-strong", mono = "g-output g-mono",
             small = "g-output g-small")
    html_el("span", c(html_slot(x), list(class = unname(cls[[x$variant]]))))
}

html_plot_output <- function(x) {
    # With no width the element fills its container and the client
    # reports the box back through a `measure` message, which is how
    # render_plot() sizes itself. The aspect fallback only rides when
    # the height is open too; a declared height -- the timeline-strip
    # shape -- already answers the question the ratio was there to
    # answer.
    style <- NULL
    if (is.null(x$width)) {
        style <- if (is.null(x$height)) {
            "width:100%;aspect-ratio:4 / 3"
        } else {
            "width:100%"
        }
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

html_video_output <- function(x) {
    # preload="metadata" always: duration and dimensions arrive, the
    # frames wait for play or a seek -- which range-requests exactly
    # what it needs instead of pulling the file to show a first frame.
    html_el("video", c(html_slot(x),
                       list(class = "g-video-output",
                            controls = if (isTRUE(x$controls)) "controls",
                            autoplay = if (isTRUE(x$autoplay)) "autoplay",
                            muted = if (isTRUE(x$muted)) "muted",
                            loop = if (isTRUE(x$loop)) "loop", preload = "metadata")))
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
