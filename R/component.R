# Protocol v3 component representation. See PROTOCOL.md.
#
# A component is a semantic description of a piece of UI -- text_input,
# column, plot_output -- not an HTML tag. Each frontend lowers it to
# its own primitives: the browser to DOM, flitR to draw ops, a future
# Dart client to Flutter widgets. Nothing here knows about any of them.

#' Declare one component field
#'
#' @param type character one of "string", "number", "int", "bool",
#'   "enum", "choices", "panels", "condition", "children", "any"
#' @param required logical must be supplied
#' @param default value filled in when absent; NULL means the field
#'   stays absent rather than becoming null on the wire
#' @param values character allowed values, for type "enum"
#' @param min,max numeric bounds, for "int" and "number"
#' @return a field spec
#' @keywords internal
field <- function(type, required = FALSE, default = NULL, values = NULL,
                  min = NULL, max = NULL) {
    list(type = type, required = required, default = default,
         values = values, min = min, max = max)
}

#' Component field schemas
#'
#' Every component's fields, with types, bounds and defaults.
#' Construction validates against this, so a malformed component fails
#' where it was written rather than in a client -- or worse, in one
#' client and not another.
#'
#' @keywords internal
COMPONENT_SCHEMA <- list(
                         # static content
                         text = list(
                                     value = field("string", required = TRUE),
                                     variant = field("enum", default = "normal",
            values = c("normal", "muted", "strong", "heading")),
                                     id = field("string")
    ),
                         heading = list(
                                        value = field("string", required = TRUE),
                                        level = field("int", default = 2L, min = 1, max = 4),
                                        id = field("string")
    ),
                         link = list(
                                     value = field("string", required = TRUE),
                                     href = field("string", required = TRUE),
                                     external = field("bool", default = FALSE)
    ),
                         icon = list(
                                     name = field("string", required = TRUE),
                                     size = field("int", default = 16L, min = 8, max = 128)
    ),
                         divider = list(
                                        label = field("string"),
                                        variant = field("enum", default = "line",
            values = c("line", "labelled"))
    ),
                         spacer = list(size = field("int", default = 1L, min = 0, max = 32)),

                         # layout
                         page = list(
                                     children = field("children", required = TRUE),
                                     title = field("string", default = "glinty app"),
                                     id = field("string")
    ),
                         row = list(
                                    children = field("children", required = TRUE),
                                    gap = field("int", min = 0, max = 128),
                                    align = field("enum", values = c("start", "center", "end")),
                                    id = field("string")
    ),
                         column = list(
                                       children = field("children", required = TRUE),
                                       gap = field("int", min = 0, max = 128),
                                       id = field("string")
    ),
                         panel = list(
                                      children = field("children", required = TRUE),
                                      variant = field("enum", default = "plain",
            values = c("plain", "card", "sidebar")),
                                      title = field("string"),
                                      id = field("string")
    ),

                         # inputs
                         #
                         # `emit` is the one field every input shares, and it is
                         # deliberately about intent rather than mechanism: "live" means
                         # report while the value is being changed, "settle" means report
                         # once it has. The browser lowers those to input/change events with
                         # a debounce; Flutter would lower them to onChanged and
                         # onEditingComplete. Naming a DOM event here would have made the
                         # schema browser-shaped.
                         text_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        value = field("string", default = ""),
        placeholder = field("string"),
        emit = field("enum", default = "live", values = c("live", "settle"))
    ),
                         password_input = list(
        # No `value` field, by schema. A field that cannot be expressed
        # cannot be rendered into page source.
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        placeholder = field("string"),
        emit = field("enum", default = "live", values = c("live", "settle"))
    ),
                         textarea_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        value = field("string", default = ""),
        rows = field("int", default = 4L, min = 1, max = 100),
        placeholder = field("string"),
        emit = field("enum", default = "live", values = c("live", "settle"))
    ),
                         number_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        value = field("number"),
        min = field("number"),
        max = field("number"),
        step = field("number"),
        emit = field("enum", default = "live", values = c("live", "settle"))
    ),
                         select_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        choices = field("choices", required = TRUE),
        selected = field("string"),
        multiple = field("bool", default = FALSE),
        emit = field("enum", default = "settle", values = c("live", "settle"))
    ),
                         checkbox_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        value = field("bool", default = FALSE),
        emit = field("enum", default = "settle", values = c("live", "settle"))
    ),
                         radio_buttons = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        choices = field("choices", required = TRUE),
        selected = field("string"),
        emit = field("enum", default = "settle", values = c("live", "settle"))
    ),
                         slider_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        min = field("number", required = TRUE),
        max = field("number", required = TRUE),
        value = field("number"),
        step = field("number"),
        emit = field("enum", default = "live", values = c("live", "settle"))
    ),
                         date_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        value = field("string"),
        min = field("string"),
        max = field("string"),
        emit = field("enum", default = "settle", values = c("live", "settle"))
    ),
                         file_input = list(
        id = field("string", required = TRUE),
        label = field("string", default = ""),
        accept = field("any"),
        multiple = field("bool", default = FALSE)
    ),

                         # events, not inputs: they carry no value the server keeps
                         button = list(
                                       id = field("string", required = TRUE),
                                       label = field("string", required = TRUE),
                                       variant = field("enum", default = "default",
            values = c("default", "primary", "secondary", "danger", "ghost")),
                                       icon = field("string")
    ),
                         download_button = list(
        id = field("string", required = TRUE),
        label = field("string", default = "Download"),
        variant = field("enum", default = "default",
                        values = c("default", "primary", "secondary", "danger", "ghost")),
        icon = field("string")
    ),

                         # outputs
                         #
                         # An output component is a slot: it names an id and says how to
                         # present whatever value arrives for it. What that value *is*
                         # comes from the renderer, as `kind` on the output message, which
                         # is why none of these carry a value field.
                         text_output = list(
        id = field("string", required = TRUE),
        variant = field("enum", default = "normal",
                        values = c("normal", "muted", "strong"))
    ),
                         verbatim_output = list(id = field("string", required = TRUE)),
                         table_output = list(id = field("string", required = TRUE)),
                         plot_output = list(
        id = field("string", required = TRUE),
        width = field("int", min = 1, max = 8192),
        height = field("int", min = 1, max = 8192),
        alt = field("string", default = "")
    ),
                         image_output = list(
        id = field("string", required = TRUE),
        alt = field("string", default = "")
    ),
                         audio_output = list(
        id = field("string", required = TRUE),
        controls = field("bool", default = TRUE),
        autoplay = field("bool", default = FALSE)
    ),
                         # Browser-only, like tag(): raw markup has no widget equivalent.
                         html_output = list(id = field("string", required = TRUE)),
                         ui_output = list(id = field("string", required = TRUE)),

                         # composite layout
                         tabset = list(
                                       id = field("string", required = TRUE),
                                       panels = field("panels", required = TRUE),
                                       selected = field("string")
    ),
                         conditional_panel = list(
        condition = field("condition", required = TRUE),
        children = field("children", required = TRUE)
    ),

                         # escape hatch
                         raw_html = list(html = field("string", required = TRUE))
)

#' Output components and the value kinds they accept
#'
#' A slot that receives a kind it cannot present is a bug worth naming
#' at render time rather than drawing nothing, so the pairing is data
#' rather than scattered through the lowerings.
#'
#' @keywords internal
OUTPUT_KINDS <- list(text_output = "text", verbatim_output = "text",
                     table_output = "table", plot_output = "image",
                     image_output = "image", audio_output = "audio",
                     ui_output = "ui")

#' What each input emits, and of what type
#'
#' Kept beside the schema rather than inside it because it describes
#' the component's protocol behaviour, not a field the wire carries.
#'
#' `message` is which client-to-server message the component produces:
#' `input` for something whose value the server keeps, `event` for a
#' discrete action it merely observes. `value_type` is what that
#' message's value must be, and is what the conformance test holds
#' both lowerings to.
#'
#' @keywords internal
INPUT_META <- list(
                   text_input = list(message = "input", value_type = "string"),
                   password_input = list(message = "input", value_type = "string"),
                   textarea_input = list(message = "input", value_type = "string"),
                   number_input = list(message = "input", value_type = "number"),
                   select_input = list(message = "input", value_type = "string"),
                   checkbox_input = list(message = "input", value_type = "bool"),
                   radio_buttons = list(message = "input", value_type = "string"),
                   slider_input = list(message = "input", value_type = "number"),
                   date_input = list(message = "input", value_type = "string"),
                   file_input = list(message = "input", value_type = "files"),
                   button = list(message = "event", value_type = NULL),
                   download_button = list(message = "event", value_type = NULL)
)

#' Is this component an input or event emitter?
#'
#' @param name character component name
#' @return logical
#' @keywords internal
is_input_component <- function(name) {
    !is.null(INPUT_META[[name]])
}

#' Construct a component
#'
#' @param type character component name, present in COMPONENT_SCHEMA
#' @param ... fields for this component
#' @return a glinty_component
#' @keywords internal
component <- function(type, ...) {
    schema <- COMPONENT_SCHEMA[[type]]
    if (is.null(schema)) {
        stop("unknown component type: ", type, call. = FALSE)
    }
    fields <- list(...)

    if (length(fields) > 0L) {
        nms <- names(fields)
        if (is.null(nms) || any(!nzchar(nms))) {
            stop(type, "() fields must all be named", call. = FALSE)
        }
        # list(value = "a", value = "b") keeps both, and [[ returns the
        # first, so the second would be silently discarded.
        if (anyDuplicated(nms) > 0L) {
            stop(type, "() got duplicate field(s): ",
                 paste(unique(nms[duplicated(nms)]), collapse = ", "),
                 call. = FALSE)
        }
    }

    unknown <- setdiff(names(fields), names(schema))
    if (length(unknown) > 0L) {
        stop(type, "() got unknown field(s): ",
             paste(unknown, collapse = ", "), ". Allowed: ",
             paste(names(schema), collapse = ", "), call. = FALSE)
    }

    out <- list()
    for (nm in names(schema)) {
        spec <- schema[[nm]]
        value <- fields[[nm]]

        # An explicit NULL is an absent field, not a present one:
        # names(list(value = NULL)) is "value", so checking names alone
        # would accept it and then drop it, yielding a component with a
        # required field missing.
        if (is.null(value)) {
            if (isTRUE(spec$required)) {
                stop(type, "() requires field '", nm, "'", call. = FALSE)
            }
            if (!is.null(spec$default)) {
                out[[nm]] <- spec$default
            }
            next
        }
        out[[nm]] <- check_field(value, spec, type, nm)
    }

    structure(c(list(component = type), out), class = "glinty_component")
}

#' Validate and normalize one field value
#'
#' @param value the supplied value
#' @param spec a field spec
#' @param type character component type, for the error message
#' @param nm character field name, for the error message
#' @return the value, coerced to its declared type
#' @keywords internal
check_field <- function(value, spec, type, nm) {
    where <- paste0(type, "(", nm, "=)")

    scalar <- function(ok, what) {
        if (length(value) != 1L || is.na(value) || !ok) {
            stop(where, " must be ", what, call. = FALSE)
        }
    }

    switch(spec$type,
           string = {
        scalar(is.character(value) || is.numeric(value), "a single string")
        return(as.character(value))
    },
           bool = {
        scalar(is.logical(value), "TRUE or FALSE")
        return(as.logical(value))
    },
           int =,
           number = {
        scalar(is.numeric(value) && is.finite(value), "a single number")
        if (identical(spec$type, "int")) {
            if (value != round(value)) {
                stop(where, " must be a whole number", call. = FALSE)
            }
            value <- as.integer(value)
        }
        if (!is.null(spec$min) && value < spec$min) {
            stop(where, " must be >= ", spec$min, call. = FALSE)
        }
        if (!is.null(spec$max) && value > spec$max) {
            stop(where, " must be <= ", spec$max, call. = FALSE)
        }
        return(value)
    },
           enum = {
        scalar(is.character(value), "a single string")
        if (!value %in% spec$values) {
            stop(where, " must be one of: ",
                 paste(spec$values, collapse = ", "), " (got '", value,
                 "')", call. = FALSE)
        }
        return(value)
    },
           panels = {
        # A tabset's panels are titled child lists rather than plain
        # components, because a tab has a name the frontend shows in
        # its own nav furniture -- Flutter builds a TabBar from these,
        # the browser builds buttons.
        if (!is.list(value) || length(value) == 0L) {
            stop(where, " must be a non-empty list of panels", call. = FALSE)
        }
        titles <- character(0L)
        out <- lapply(seq_along(value), function(i) {
            p <- value[[i]]
            if (!is.list(p) || is.null(p$title) || !nzchar(p$title)) {
                stop(where, " panel ", i, " needs a non-empty title",
                     call. = FALSE)
            }
            titles <<- c(titles, p$title)
            list(title = as.character(p$title),
                 children = check_children(
                    if (is.null(p$children)) list() else p$children,
                    paste0(type, " panel ", i)))
        })
        if (anyDuplicated(titles) > 0L) {
            stop(where, " titles must be unique; duplicated: ",
                 paste(unique(titles[duplicated(titles)]), collapse = ", "),
                 call. = FALSE)
        }
        return(unname(out))
    },
           condition = {
        if (!inherits(value, "glinty_condition")) {
            stop(where, " must be a condition from input_is(), cond_and(), ",
                 "cond_or() or cond_not()", call. = FALSE)
        }
        return(unclass(value))
    },
           choices = {
        # A named character vector is the R-idiomatic way to write
        # choices and the wire form is a list of {value, label}, so
        # normalize here rather than making every builder do it.
        if (is.character(value) || is.numeric(value)) {
            labels <- names(value)
            if (is.null(labels)) {
                labels <- as.character(value)
            }
            labels[!nzchar(labels)] <- as.character(value)[!nzchar(labels)]
            value <- lapply(seq_along(value), function(i) {
                list(value = as.character(value[[i]]),
                     label = as.character(labels[[i]]))
            })
        }
        if (!is.list(value) || length(value) == 0L) {
            stop(where, " must be a non-empty vector or list of choices",
                 call. = FALSE)
        }
        for (i in seq_along(value)) {
            ch <- value[[i]]
            if (!is.list(ch) || is.null(ch$value) || is.null(ch$label)) {
                stop(where, " choice ", i,
                     " must have both a value and a label", call. = FALSE)
            }
        }
        return(unname(value))
    },
           children = {
        if (!is.list(value)) {
            stop(where, " must be a list of components", call. = FALSE)
        }
        return(check_children(value, type))
    },
           any = return(value)
    )
    stop("unknown field type in schema: ", spec$type, call. = FALSE)
}

#' Is this a component?
#'
#' @param x any object
#' @return logical
#' @keywords internal
is_component <- function(x) {
    inherits(x, "glinty_component")
}

#' Validate a list of children
#'
#' NULLs are dropped so conditional children compose, but the index in
#' the error message is the caller's original one -- reporting a
#' post-filter index sends people looking at the wrong argument.
#'
#' Reached through check_field() rather than called directly, so a
#' builder cannot forget it.
#'
#' @param children list of candidate children
#' @param fn character calling function, for the error message
#' @return the list, filtered and unnamed
#' @keywords internal
check_children <- function(children, fn) {
    keep <- !vapply(children, is.null, logical(1L))
    for (i in seq_along(children)) {
        if (!keep[[i]] || is_component(children[[i]])) {
            next
        }
        stop(fn, "() child ", i, " is not a component (got ",
             paste(class(children[[i]]), collapse = "/"), "). ",
             "Wrap plain strings in text().", call. = FALSE)
    }
    unname(children[keep])
}

#' Print a component as its wire form
#'
#' Shows exactly what a client receives, which is the useful view when
#' the question is why a frontend rendered something unexpected.
#'
#' @param x a glinty_component
#' @param ... ignored
#' @return x, invisibly
#' @examples
#' \dontrun{
#' print(glinty:::component("text", value = "hello"))
#' }
#' @export
print.glinty_component <- function(x, ...) {
    cat(as.character(jsonlite::toJSON(unclass_recursive(x), auto_unbox = TRUE,
                                      pretty = TRUE)),
        "\n")
    invisible(x)
}

#' The protocol version this glinty speaks
#'
#' Carried in the fixture artifact and, from stage 2, in `hello` and
#' `welcome`, so a client can refuse a wire format it was not written
#' against rather than rendering half of it.
#'
#' @keywords internal
PROTOCOL_VERSION <- 3L
