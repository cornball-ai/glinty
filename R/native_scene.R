# Tag-tree -> flitR op translation for the native backend. Pure with
# respect to flitR state: builds op lists; scene()/widget registration
# happens in the native loop. Widget callbacks call glinty's input
# handlers directly -- the JSON protocol only flows downward (output
# updates through native_apply).

NATIVE_HEADING_SIZES <- c(h1 = 24, h2 = 20, h3 = 17, h4 = 15)

#' Build flitR ops for a glinty UI tree
#'
#' @param ui a glinty_tag tree from page()
#' @param session the native glinty_session
#' @param values env of output id -> latest client-ready value
#' @return list of flitR ops/widgets (nested; scene() flattens)
#' @keywords internal
build_native_ops <- function(ui, session, values) {
    unsupported <- new.env(parent = emptyenv())
    unsupported$tags <- character(0L)

    items <- translate_tags(ui$children, session, values, unsupported)

    if (length(unsupported$tags) > 0L) {
        stop("the flitR native backend does not support: ",
             paste(sort(unique(unsupported$tags)), collapse = ", "),
             call. = FALSE)
    }
    list(
         flitR::clear("#FFFFFF"),
         do.call(flitR::column, c(items, list(x = 16, y = 16, gap = 10)))
    )
}

#' Translate a list of child tags
#'
#' @param children list of glinty_tag or character
#' @param session the native session
#' @param values output value env
#' @param unsupported collector env
#' @return list of flitR items
#' @keywords internal
translate_tags <- function(children, session, values, unsupported) {
    items <- list()
    for (child in children) {
        out <- translate_tag(child, session, values, unsupported)
        if (!is.null(out)) {
            items <- c(items, list(out))
        }
    }
    items
}

#' Translate one tag
#'
#' @param tg a glinty_tag or character
#' @param session the native session
#' @param values output value env
#' @param unsupported collector env
#' @return a flitR item, or NULL to skip
#' @keywords internal
translate_tag <- function(tg, session, values, unsupported) {
    if (is.character(tg)) {
        return(flitR::text(0, 0, tg, size = 14))
    }
    if (!inherits(tg, "glinty_tag")) {
        return(NULL)
    }
    name <- tg$tag
    cls <- tg$attrs$class

    if (name %in% names(NATIVE_HEADING_SIZES)) {
        return(flitR::text(0, 0, tag_text(tg),
                           size = NATIVE_HEADING_SIZES[[name]]))
    }
    if (name %in% c("p", "span")) {
        if (identical(cls, "g-output")) {
            return(flitR::text(0, 0, native_value(values, tg$attrs$id),
                               size = 14))
        }
        if (identical(cls, "g-slider-val")) {
            return(NULL)
        }
        return(flitR::text(0, 0, tag_text(tg), size = 14))
    }
    if (name == "a") {
        return(flitR::text(0, 0, tag_text(tg), size = 14, color = "#2456D6"))
    }
    if (name == "label") {
        txt <- tag_text(tg)
        if (!nzchar(txt)) {
            return(NULL)
        }
        return(flitR::text(0, 0, txt, size = 12, color = "#666666"))
    }
    if (name == "button" && !is.null(tg$bind)) {
        id <- tg$bind$target
        label <- tag_text(tg)
        return(flitR::button(id, 0, 0,
                             w = 24 + 9 * nchar(label), h = 34, label = label,
                             on_click = function() {
            handle_click(session, id)
        }))
    }
    if (name == "input") {
        return(translate_input(tg, session, unsupported))
    }
    if (name == "img" && identical(cls, "g-plot-output")) {
        return(translate_plot(tg, values))
    }
    if (name == "div") {
        if (identical(cls, "g-radio-group")) {
            unsupported$tags <- c(unsupported$tags, "radio_buttons")
            return(NULL)
        }
        if (identical(cls, "g-html-output")) {
            unsupported$tags <- c(unsupported$tags, "html_output")
            return(NULL)
        }
        if (identical(cls, "g-table-output")) {
            unsupported$tags <- c(unsupported$tags, "table_output")
            return(NULL)
        }
        # generic containers (including input groups): stack children
        items <- translate_tags(tg$children, session, values, unsupported)
        if (length(items) == 0L) {
            return(NULL)
        }
        return(do.call(flitR::column, c(items, list(gap = 4))))
    }
    if (name == "select") {
        unsupported$tags <- c(unsupported$tags, "select_input")
        return(NULL)
    }
    if (name == "textarea") {
        unsupported$tags <- c(unsupported$tags, "textarea_input")
        return(NULL)
    }
    if (name == "audio") {
        unsupported$tags <- c(unsupported$tags, "audio_output")
        return(NULL)
    }
    unsupported$tags <- c(unsupported$tags, name)
    NULL
}

#' Translate a leaf input element
#'
#' @param tg the input glinty_tag
#' @param session the native session
#' @param unsupported collector env
#' @return a flitR widget or NULL
#' @keywords internal
translate_input <- function(tg, session, unsupported) {
    type <- tg$attrs$type
    if (!is.null(tg$bind)) {
        id <- tg$bind$target
    } else {
        id <- tg$attrs$id
    }

    if (identical(type, "text")) {
        cur <- isolate(session$input[[id]]())
        if (is.null(cur)) {
            cur <- tg$attrs$value
        }
        if (is.null(cur)) {
            cur <- ""
        }
        return(flitR::input(id, 0, 0, w = 260, h = 32,
                            value = as.character(cur),
                            on_change = function(v) {
            handle_input(session, id, v)
        }))
    }
    if (identical(type, "checkbox")) {
        cur <- isolate(session$input[[id]]())
        checked <- if (is.null(cur)) {
            !is.null(tg$attrs$checked)
        } else {
            isTRUE(cur)
        }
        return(flitR::checkbox(id, 0, 0, size = 22, value = checked,
                               on_change = function(v) {
            handle_input(session, id, v)
        }))
    }
    if (identical(type, "range")) {
        cur <- isolate(session$input[[id]]())
        val <- if (is.null(cur)) {
            as.numeric(tg$attrs$value)
        } else {
            as.numeric(cur)
        }
        return(flitR::slider(id, 0, 0, w = 260, h = 24,
                             value = val,
                             min = as.numeric(tg$attrs$min),
                             max = as.numeric(tg$attrs$max),
                             on_change = function(v) {
            handle_input(session, id, v)
        }))
    }
    kind <- switch(type, "number" = "number_input", "date" = "date_input",
                   "file" = "file_input", "radio" = "radio_buttons",
                   paste0("input[type=", type, "]"))
    unsupported$tags <- c(unsupported$tags, kind)
    NULL
}

#' Translate a plot output
#'
#' render_plot() values arrive as PNG data URIs; the base64 passes
#' straight into flitR's image op. Before the first render, a light
#' placeholder rect holds the space.
#'
#' @param tg the img glinty_tag
#' @param values output value env
#' @return a flitR item
#' @keywords internal
translate_plot <- function(tg, values) {
    w <- suppressWarnings(as.numeric(tg$attrs$width))
    h <- suppressWarnings(as.numeric(tg$attrs$height))
    if (length(w) != 1L || is.na(w)) {
        w <- 480
    }
    if (length(h) != 1L || is.na(h)) {
        h <- 360
    }
    uri <- native_value(values, tg$attrs$id)
    if (startsWith(uri, "data:image/png;base64,")) {
        return(flitR::image(0, 0, w, h,
                            sub("^data:image/png;base64,", "", uri)))
    }
    flitR::rect(0, 0, w, h, color = "#EEEEEE")
}

#' Current client-ready value of an output
#'
#' @param values output value env
#' @param id character output id
#' @return character value ("" before the first update)
#' @keywords internal
native_value <- function(values, id) {
    if (is.null(id)) {
        return("")
    }
    v <- values[[id]]
    if (is.null(v)) {
        ""
    } else {
        as.character(v)
    }
}

#' Concatenate a tag's text content
#'
#' @param tg a glinty_tag
#' @return character
#' @keywords internal
tag_text <- function(tg) {
    if (!is.null(tg$text)) {
        return(tg$text)
    }
    chars <- Filter(is.character, tg$children)
    paste(unlist(chars), collapse = " ")
}
