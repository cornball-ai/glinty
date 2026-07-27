# Protocol v3 component representation. See PROTOCOL.md.
#
# A component is a semantic description of a piece of UI -- text_input,
# column, plot_output -- not an HTML tag. Each frontend lowers it to
# its own primitives: the browser to DOM, flitR to draw ops, a future
# Dart client to Flutter widgets. Nothing here knows about any of them.

#' Declare one component field
#'
#' @param type character one of "string", "number", "int", "bool",
#'   "enum", "children", "any"
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

                         # escape hatch
                         raw_html = list(html = field("string", required = TRUE))
)

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
