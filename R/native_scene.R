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
    if (name == "pre" && identical(cls, "g-verbatim-output")) {
        return(flitR::text(0, 0, native_value(values, tg$attrs$id), size = 13))
    }
    if (name == "a") {
        # A download link has no native counterpart, and drawing it as
        # ordinary blue text would be a button that silently does
        # nothing. Say so instead.
        if (!is.null(tg$attrs[["data-g-download"]])) {
            unsupported$tags <- c(unsupported$tags, "download_button")
            return(NULL)
        }
        return(flitR::text(0, 0, tag_text(tg), size = 14, color = "#2456D6"))
    }
    if (name == "label") {
        txt <- tag_text(tg)
        if (!nzchar(txt)) {
            return(NULL)
        }
        return(flitR::text(0, 0, txt, size = 12, color = "#666666"))
    }
    if (name == "button" && !is.null(tg$attrs[["data-g-modal-close"]])) {
        unsupported$tags <- c(unsupported$tags, "modal_button")
        return(NULL)
    }
    if (name == "button" && !is.null(tg$attrs[["data-g-tab-panel"]])) {
        unsupported$tags <- c(unsupported$tags, "tabset")
        return(NULL)
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
        if (identical(cls, "g-layout-row") || identical(cls, "g-layout-col")) {
            items <- translate_tags(tg$children, session, values, unsupported)
            if (length(items) == 0L) {
                return(NULL)
            }
            gap <- suppressWarnings(as.numeric(tg$attrs[["data-g-gap"]]))
            if (length(gap) != 1L || is.na(gap)) {
                if (identical(cls, "g-layout-row")) {
                    gap <- 12
                } else {
                    gap <- 8
                }
            }
            layout_fn <- if (identical(cls, "g-layout-row")) {
                flitR::row
            } else {
                flitR::column
            }
            return(do.call(layout_fn, c(items, list(gap = gap))))
        }
        if (identical(cls, "g-tabset")) {
            return(translate_tabset(tg, session, values, unsupported))
        }
        if (identical(cls, "g-conditional")) {
            # Evaluated server-side against the same inputs the client
            # would use, so the two frontends agree on what shows.
            # flitR's dirty flag rebuilds the scene on any state
            # write, so the panel re-evaluates when an input changes.
            cond <- tag_condition(tg)
            if (is.null(cond) || !eval_condition(cond, session)) {
                return(NULL)
            }
            items <- translate_tags(tg$children, session, values, unsupported)
            if (length(items) == 0L) {
                return(NULL)
            }
            return(do.call(flitR::column, c(items, list(gap = 4))))
        }
        if (identical(cls, "g-radio-group")) {
            unsupported$tags <- c(unsupported$tags, "radio_buttons")
            return(NULL)
        }
        if (identical(cls, "g-html-output")) {
            unsupported$tags <- c(unsupported$tags, "html_output")
            return(NULL)
        }
        if (identical(cls, "g-table-output")) {
            return(translate_table(tg, values))
        }
        if (identical(cls, "g-ui-output")) {
            if (is.null(tg$attrs$id)) {
                tree <- NULL
            } else {
                tree <- values[[tg$attrs$id]]
            }
            if (is.null(tree)) {
                return(NULL)
            }
            return(translate_tag(rehydrate_tag(tree), session, values,
                                 unsupported))
        }
        # generic containers (including input groups): stack children
        items <- translate_tags(tg$children, session, values, unsupported)
        if (length(items) == 0L) {
            return(NULL)
        }
        return(do.call(flitR::column, c(items, list(gap = 4))))
    }
    if (name == "select") {
        if (!is.null(tg$bind)) {
            id <- tg$bind$target
        } else {
            id <- tg$attrs$id
        }
        opts <- Filter(function(ch) {
            inherits(ch, "glinty_tag") && identical(ch$tag, "option")
        }, tg$children)
        vals <- vapply(opts, function(o) as.character(o$attrs$value),
                       character(1L))
        labs <- vapply(opts, function(o) {
            if (is.null(o$text)) as.character(o$attrs$value) else o$text
        }, character(1L))
        choices <- vals
        names(choices) <- labs
        cur <- isolate(session$input[[id]]())
        if (is.null(cur)) {
            marked <- which(vapply(opts, function(o) {
                !is.null(o$attrs$selected)
            }, logical(1L)))
            cur <- if (length(marked) > 0L) {
                vals[[marked[[1L]]]]
            } else if (length(vals) > 0L) {
                vals[[1L]]
            } else {
                NULL
            }
        }
        return(flitR::select(id, 0, 0, w = 200, h = 32,
                             value = cur, choices = choices,
                             on_change = function(v) {
            handle_input(session, id, v)
        }))
    }
    if (name == "textarea") {
        if (!is.null(tg$bind)) {
            id <- tg$bind$target
        } else {
            id <- tg$attrs$id
        }
        cur <- isolate(session$input[[id]]())
        if (is.null(cur)) {
            if (is.null(tg$text)) {
                cur <- ""
            } else {
                cur <- tg$text
            }
        }
        n_rows <- suppressWarnings(as.numeric(tg$attrs$rows))
        if (length(n_rows) != 1L || is.na(n_rows)) {
            n_rows <- 4
        }
        return(flitR::textarea(id, 0, 0, w = 300, rows = n_rows,
                               value = as.character(cur),
                               on_change = function(v) {
            handle_input(session, id, v)
        }))
    }
    if (name == "audio") {
        unsupported$tags <- c(unsupported$tags, "audio_output")
        return(NULL)
    }
    unsupported$tags <- c(unsupported$tags, name)
    NULL
}

#' Translate a tabset
#'
#' The nav strip comes from flitR::tabs(); below it only the selected
#' panel is emitted. That is the immediate-mode reading of a tab: an
#' unselected panel is not hidden, it is simply not drawn this frame,
#' which is also why the browser's DOM-preserving behaviour (inputs
#' keeping their values while hidden) does not carry over.
#'
#' Switching needs somewhere to hold the selection, and the only
#' durable place is the tabset's own input. A tabset without an id has
#' nowhere to put it, so rather than draw a nav that does nothing when
#' clicked, say so.
#'
#' @param tg the g-tabset glinty_tag
#' @param session the native session
#' @param values output value env
#' @param unsupported collector env
#' @return a flitR item, or NULL
#' @keywords internal
translate_tabset <- function(tg, session, values, unsupported) {
    id <- tg$attrs$id
    if (is.null(id)) {
        unsupported$tags <- c(unsupported$tags,
                              "tabset without an id (native tabs need one to hold the selection)")
        return(NULL)
    }

    nav <- tab_child(tg, "g-tab-nav")
    bodies <- tab_child(tg, "g-tab-bodies")
    if (is.null(nav) || is.null(bodies)) {
        return(NULL)
    }

    labels <- vapply(nav$children, function(b) {
        as.character(b$attrs[["data-g-tab-panel"]])
    }, character(1L))
    if (length(labels) == 0L) {
        return(NULL)
    }

    selected <- isolate(session$input[[id]]())
    if (!is.character(selected) || length(selected) != 1L ||
        !selected %in% labels) {
        # Fall back to whichever button the UI marked active.
        active <- Filter(function(b) {
            grepl("g-tab-active", as.character(b$attrs$class), fixed = TRUE)
        }, nav$children)
        selected <- if (length(active) > 0L) {
            as.character(active[[1L]]$attrs[["data-g-tab-panel"]])
        } else {
            labels[[1L]]
        }
    }

    strip <- flitR::tabs(id, 0, 0, labels, selected = selected,
                         on_select = function(label) {
        handle_input(session, id, label)
    })

    body <- Filter(function(b) {
        identical(as.character(b$attrs[["data-g-tab-panel"]]), selected)
    }, bodies$children)

    items <- list(strip)
    if (length(body) > 0L) {
        panel <- translate_tags(body[[1L]]$children, session, values,
                                unsupported)
        if (length(panel) > 0L) {
            items <- c(items, list(do.call(flitR::column,
                        c(panel, list(gap = 8)))))
        }
    }
    do.call(flitR::column, c(items, list(gap = 10)))
}

#' Find a direct child of a tabset by class
#'
#' @param tg the g-tabset glinty_tag
#' @param cls character class to match
#' @return the matching child, or NULL
#' @keywords internal
tab_child <- function(tg, cls) {
    hit <- Filter(function(ch) {
        inherits(ch, "glinty_tag") && identical(as.character(ch$attrs$class),
            cls)
    }, tg$children)
    if (length(hit) == 0L) {
        return(NULL)
    }
    hit[[1L]]
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

    # Password is the same widget with mask = TRUE: flitR draws bullets
    # while the real string stays in R, so nothing secret reaches the
    # renderer.
    if (identical(type, "text") || identical(type, "password")) {
        cur <- isolate(session$input[[id]]())
        if (is.null(cur)) {
            cur <- tg$attrs$value
        }
        if (is.null(cur)) {
            cur <- ""
        }
        return(flitR::input(id, 0, 0, w = 260, h = 32,
                            value = as.character(cur),
                            placeholder = if (is.null(tg$attrs$placeholder)) {
                    ""
                } else {
                    as.character(tg$attrs$placeholder)
                },
                            mask = identical(type, "password"),
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
    if (identical(type, "number")) {
        cur <- isolate(session$input[[id]]())
        if (is.null(cur)) {
            cur <- suppressWarnings(as.numeric(tg$attrs$value))
        }
        if (length(cur) != 1L || is.na(cur)) {
            cur <- NULL
        }
        return(flitR::number(id, 0, 0, w = 120, h = 32,
                             value = cur,
                             on_change = function(v) {
            handle_input(session, id, v)
        }))
    }
    kind <- switch(type, "date" = "date_input", "file" = "file_input",
                   "radio" = "radio_buttons", paste0("input[type=", type, "]"))
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

#' Draw a structured table as a native grid
#'
#' Consumes the wire table format ({header, rows}) stored by
#' native_apply. Column widths from a character-count heuristic;
#' text self-corrects via flitR's measurement cache like all native
#' text. Empty until the first update arrives.
#'
#' @param tg the table_output div tag
#' @param values output value env
#' @return list of flitR ops, or NULL before the first update
#' @keywords internal
translate_table <- function(tg, values) {
    id <- tg$attrs$id
    if (is.null(id)) {
        data <- NULL
    } else {
        data <- values[[id]]
    }
    if (is.null(data) || is.null(data$header)) {
        return(NULL)
    }
    header <- vapply(data$header, as.character, character(1L))
    rows <- lapply(data$rows, function(r) {
        vapply(r, as.character, character(1L))
    })
    n_col <- length(header)
    if (n_col == 0L) {
        return(NULL)
    }
    col_w <- vapply(seq_len(n_col), function(j) {
        cells <- c(header[[j]], vapply(rows, function(r) {
            if (j <= length(r)) r[[j]] else ""
        }, character(1L)))
        max(nchar(cells)) * 8 + 16
    }, numeric(1L))
    row_h <- 24
    xs <- cumsum(c(0, col_w))[seq_len(n_col)]

    ops <- list()
    grid_row <- function(cells, y, is_header) {
        for (j in seq_along(cells)) {
            ops[[length(ops) + 1L]] <<- flitR::rect(xs[[j]], y, col_w[[j]],
                row_h, "#CCCCCC")
            ops[[length(ops) + 1L]] <<- flitR::rect(xs[[j]] + 1, y + 1,
                col_w[[j]] - 2, row_h - 2,
                if (is_header) "#EEEEEE" else "#FFFFFF")
            ops[[length(ops) + 1L]] <<- flitR::text(xs[[j]] + 8, y + 5,
                cells[[j]], size = 13,
                color = if (is_header) "#111111" else "#333333")
        }
    }
    grid_row(header, 0, TRUE)
    for (i in seq_along(rows)) {
        grid_row(rows[[i]], i * row_h, FALSE)
    }
    ops
}

#' Seed session inputs from the UI tree's initial values
#'
#' The browser client harvests rendered DOM values into its init
#' message; this is the native equivalent, walking the tag tree for
#' widget defaults so input$x() matches what the window shows.
#'
#' @param tg a glinty_tag (or character, ignored)
#' @param session the native session
#' @return invisible(NULL)
#' @keywords internal
harvest_native_inputs <- function(tg, session) {
    if (!inherits(tg, "glinty_tag")) {
        return(invisible(NULL))
    }
    if (!is.null(tg$bind)) {
        id <- tg$bind$target
    } else {
        id <- NULL
    }
    if (!is.null(id)) {
        if (identical(tg$tag, "input")) {
            type <- tg$attrs$type
            if ((identical(type, "text") || identical(type, "password")) &&
                !is.null(tg$attrs$value)) {
                handle_input(session, id, tg$attrs$value)
            } else if (identical(type, "checkbox")) {
                handle_input(session, id, !is.null(tg$attrs$checked))
            } else if (identical(type, "range") || identical(type, "number")) {
                v <- suppressWarnings(as.numeric(tg$attrs$value))
                if (length(v) == 1L && !is.na(v)) {
                    handle_input(session, id, v)
                }
            }
        } else if (identical(tg$tag, "textarea")) {
            handle_input(session, id, if (is.null(tg$text)) "" else tg$text)
        } else if (identical(tg$tag, "select")) {
            opts <- Filter(function(ch) {
                inherits(ch, "glinty_tag") && identical(ch$tag, "option")
            }, tg$children)
            marked <- Filter(function(o) !is.null(o$attrs$selected), opts)
            pick <- if (length(marked) > 0L) {
                marked[[1L]]
            } else if (length(opts) > 0L) {
                opts[[1L]]
            } else {
                NULL
            }
            if (!is.null(pick)) {
                handle_input(session, id, as.character(pick$attrs$value))
            }
        } else if (identical(tg$tag, "button") &&
            !is.null(tg$attrs[["data-g-tab-panel"]]) &&
            grepl("g-tab-active", as.character(tg$attrs$class), fixed = TRUE)) {
            # The open tab is state, not an event, so the server knows
            # it from the start -- same as the browser's init harvest.
            handle_input(session, id,
                         as.character(tg$attrs[["data-g-tab-panel"]]))
        }
    }
    for (child in tg$children) {
        harvest_native_inputs(child, session)
    }
    invisible(NULL)
}

#' Rebuild a glinty_tag tree from parsed wire JSON
#'
#' render_ui() ships unclassed tag trees; the native side rebuilds
#' the class so translate_tag() can walk them like static UI.
#'
#' @param x parsed JSON node (named list, character, or NULL)
#' @return a glinty_tag, character, or NULL
#' @keywords internal
rehydrate_tag <- function(x) {
    if (is.character(x)) {
        return(x)
    }
    if (!is.list(x) || is.null(x$tag)) {
        return(NULL)
    }
    if (is.null(x$children)) {
        kids <- list()
    } else {
        kids <- x$children
    }
    structure(
              list(tag = x$tag, attrs = if (is.null(x$attrs)) list() else x$attrs,
                   text = x$text,
                   children = Filter(Negate(is.null), lapply(kids, rehydrate_tag)),
                   bind = x$bind),
              class = "glinty_tag"
    )
}
