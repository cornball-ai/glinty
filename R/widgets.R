#' Create a text input
#'
#' @param id character input ID
#' @param label character label text
#' @param value character initial value
#' @param placeholder character placeholder text
#' @return A UI element
#' @examples
#' text_input("name", "Name:")
#' @export
text_input <- function(id, label = "", value = "", placeholder = "") {
    attrs <- list(id = id, type = "text", class = "g-input", value = value)
    if (nzchar(placeholder)) {
        attrs$placeholder <- placeholder
    }
    tag(
        "div",
        attrs = list(class = "g-input-group"),
        children = list(
                        tag("label", text = label, attrs = list("for" = id)),
                        tag("input", attrs = attrs,
                            bind = list(event = "input", target = id))
        )
    )
}

#' Create a multi-line text input
#'
#' @param id character input ID
#' @param label character label text
#' @param value character initial value
#' @param rows integer number of visible rows
#' @param placeholder character placeholder text
#' @return A UI element
#' @examples
#' textarea_input("notes", "Notes:", rows = 6L)
#' @export
textarea_input <- function(id, label = "", value = "", rows = 4L,
                           placeholder = "") {
    tag(
        "div",
        attrs = list(class = "g-input-group"),
        children = list(
                        tag("label", text = label, attrs = list("for" = id)),
                        tag("textarea",
                            text = value,
                            attrs = list(id = id, class = "g-textarea",
                    rows = as.character(rows),
                    placeholder = placeholder),
                            bind = list(event = "input", target = id))
        )
    )
}

#' Create a checkbox input
#'
#' @param id character input ID
#' @param label character label text
#' @param value logical initial checked state
#' @return A UI element
#' @examples
#' checkbox_input("save", "Save results", value = TRUE)
#' @export
checkbox_input <- function(id, label = "", value = FALSE) {
    attrs <- list(id = id, type = "checkbox", class = "g-checkbox")
    if (isTRUE(value)) {
        attrs$checked <- "checked"
    }
    tag(
        "div",
        attrs = list(class = "g-checkbox-group"),
        children = list(
                        tag("input", attrs = attrs,
                            bind = list(event = "change", target = id)),
                        tag("label", text = label, attrs = list("for" = id))
        )
    )
}

#' Create a select dropdown
#'
#' @param id character input ID
#' @param label character label text
#' @param choices character vector of choices; names are display labels
#' @param selected character value to select initially
#' @return A UI element
#' @examples
#' select_input("engine", "Engine:", c(Fast = "fast", Slow = "slow"))
#' @export
select_input <- function(id, label = "", choices = character(0),
                         selected = NULL) {
    if (is.null(names(choices))) {
        names(choices) <- choices
    }
    if (is.null(selected) && length(choices) > 0L) {
        selected <- choices[[1L]]
    }
    options <- lapply(seq_along(choices), function(i) {
        attrs <- list(value = choices[[i]])
        if (identical(choices[[i]], selected)) attrs$selected <- "selected"
        tag("option", text = names(choices)[[i]], attrs = attrs)
    })
    tag(
        "div",
        attrs = list(class = "g-input-group"),
        children = list(
                        tag("label", text = label, attrs = list("for" = id)),
                        tag("select", attrs = list(id = id, class = "g-select"),
                            children = options, bind = list(event = "change", target = id))
        )
    )
}

#' Create a range slider input
#'
#' @param id character input ID
#' @param label character label text
#' @param min numeric minimum value
#' @param max numeric maximum value
#' @param value numeric initial value
#' @param step numeric step size
#' @return A UI element
#' @examples
#' slider_input("n", "Points:", min = 10, max = 500, value = 100, step = 10)
#' @export
slider_input <- function(id, label = "", min = 0, max = 1, value = 0.5,
                         step = 0.1) {
    tag(
        "div",
        attrs = list(class = "g-slider-group"),
        children = list(
                        tag("label", text = label, attrs = list("for" = id)),
                        tag("input",
                            attrs = list(id = id, type = "range", class = "g-slider",
                    min = as.character(min), max = as.character(max),
                    value = as.character(value),
                    step = as.character(step)),
                            bind = list(event = "input", target = id)),
                        tag("span",
                            text = as.character(value),
                            attrs = list(id = paste0(id, "_val"), class = "g-slider-val"))
        )
    )
}

#' Create a numeric input
#'
#' @param id character input ID
#' @param label character label text
#' @param value numeric initial value
#' @param min numeric minimum (optional)
#' @param max numeric maximum (optional)
#' @param step numeric step size (optional)
#' @return A UI element
#' @examples
#' number_input("k", "Clusters:", value = 3, min = 1, max = 10)
#' @export
number_input <- function(id, label = "", value = NULL, min = NULL,
                         max = NULL, step = NULL) {
    attrs <- list(id = id, type = "number", class = "g-number")
    if (!is.null(value)) {
        attrs$value <- as.character(value)
    }
    if (!is.null(min)) {
        attrs$min <- as.character(min)
    }
    if (!is.null(max)) {
        attrs$max <- as.character(max)
    }
    if (!is.null(step)) {
        attrs$step <- as.character(step)
    }
    tag(
        "div",
        attrs = list(class = "g-input-group"),
        children = list(
                        tag("label", text = label, attrs = list("for" = id)),
                        tag("input", attrs = attrs,
                            bind = list(event = "input", target = id))
        )
    )
}

#' Create a button
#'
#' Clicks increment the input value (action-button semantics), so
#' observe_event(input$id, ...) fires once per click.
#'
#' @param id character button ID
#' @param label character button label
#' @return A UI element
#' @examples
#' button("go", "Run")
#' @export
button <- function(id, label) {
    tag("button", text = label, attrs = list(id = id, class = "g-btn"),
        bind = list(event = "click", target = id))
}

#' Create a file input
#'
#' Files upload over a plain POST (not the WebSocket); when the
#' upload completes, the input value becomes a data.frame with one
#' row per file: name, size, type, datapath. The datapath points at
#' a server-side copy in a per-session temp dir removed when the
#' session ends. Size is capped by getOption("glinty.max_upload")
#' (10 MB default).
#'
#' @param id character input ID
#' @param label character label text
#' @param accept character vector of accepted types/extensions,
#'   e.g. c(".csv", "image/png") (optional)
#' @param multiple logical allow selecting several files
#' @return A UI element
#' @examples
#' file_input("dataset", "CSV:", accept = ".csv")
#' @export
file_input <- function(id, label = "", accept = NULL, multiple = FALSE) {
    attrs <- list(id = id, type = "file", class = "g-file")
    attrs[["data-g-upload"]] <- id
    if (!is.null(accept)) {
        attrs$accept <- paste(accept, collapse = ",")
    }
    if (isTRUE(multiple)) {
        attrs$multiple <- "multiple"
    }
    tag(
        "div",
        attrs = list(class = "g-input-group"),
        children = list(
                        tag("label", text = label, attrs = list("for" = id)),
                        tag("input", attrs = attrs)
        )
    )
}

#' Create a radio button group
#'
#' One input value shared by the group: the checked member's value.
#'
#' @param id character input ID (also the shared name of the group)
#' @param label character group label text
#' @param choices character vector of choices; names are display labels
#' @param selected character value checked initially (first choice by
#'   default)
#' @return A UI element
#' @examples
#' radio_buttons("mode", "Mode:", c(Fast = "fast", Careful = "careful"))
#' @export
radio_buttons <- function(id, label = "", choices = character(0),
                          selected = NULL) {
    if (is.null(names(choices))) {
        names(choices) <- choices
    }
    if (is.null(selected) && length(choices) > 0L) {
        selected <- choices[[1L]]
    }
    items <- lapply(seq_along(choices), function(i) {
        item_id <- paste0(id, "_", i)
        attrs <- list(id = item_id, type = "radio", name = id,
            value = choices[[i]], class = "g-radio")
        if (identical(choices[[i]], selected)) {
            attrs$checked <- "checked"
        }
        tag(
            "div",
            attrs = list(class = "g-radio-item"),
            children = list(
                            tag("input", attrs = attrs,
                                bind = list(event = "change", target = id)),
                            tag("label", text = names(choices)[[i]],
                                attrs = list("for" = item_id))
            )
        )
    })
    tag(
        "div",
        attrs = list(id = id, class = "g-radio-group"),
        children = c(
            list(tag("label", text = label,
                attrs = list(class = "g-radio-group-label"))),
            items
        )
    )
}

#' Create a date input
#'
#' The input value arrives server-side as a "YYYY-MM-DD" string;
#' convert with as.Date() at the point of use. No hidden coercion.
#'
#' @param id character input ID
#' @param label character label text
#' @param value character initial date, "YYYY-MM-DD" (optional)
#' @param min character earliest selectable date (optional)
#' @param max character latest selectable date (optional)
#' @return A UI element
#' @examples
#' date_input("start", "Start:", value = "2026-07-07")
#' @export
date_input <- function(id, label = "", value = NULL, min = NULL,
                       max = NULL) {
    attrs <- list(id = id, type = "date", class = "g-date")
    if (!is.null(value)) {
        attrs$value <- as.character(value)
    }
    if (!is.null(min)) {
        attrs$min <- as.character(min)
    }
    if (!is.null(max)) {
        attrs$max <- as.character(max)
    }
    tag(
        "div",
        attrs = list(class = "g-input-group"),
        children = list(
                        tag("label", text = label, attrs = list("for" = id)),
                        tag("input", attrs = attrs,
                            bind = list(event = "change", target = id))
        )
    )
}
