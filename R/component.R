# Protocol v3 component representation. See PROTOCOL.md.
#
# A component is a semantic description of a piece of UI -- text_input,
# column, plot_output -- not an HTML tag. Each frontend lowers it to
# its own primitives: the browser to DOM, flitR to draw ops, a future
# Dart client to Flutter widgets. Nothing here knows about any of them.

#' Component field schemas
#'
#' Declares every component's required and optional fields, plus
#' defaults for the optional ones. Construction validates against this,
#' so a malformed component fails where it was written rather than in a
#' client.
#'
#' `children` is called out separately because it nests components
#' rather than holding scalars, and lowerings recurse on it.
#'
#' @keywords internal
COMPONENT_SCHEMA <- list(
                         # static content
                         text = list(required = "value",
                                     optional = list(variant = "normal", id = NULL)),
                         heading = list(required = "value", optional = list(level = 2L, id = NULL)),
                         link = list(required = c("value", "href"),
                                     optional = list(external = FALSE)),
                         icon = list(required = "name", optional = list(size = 16L)),
                         divider = list(required = character(0L),
                                        optional = list(label = NULL, variant = "line")),
                         spacer = list(required = character(0L), optional = list(size = 1L)),

                         # layout
                         page = list(required = "children",
                                     optional = list(title = "glinty app", id = NULL)),
                         row = list(required = "children",
                                    optional = list(gap = NULL, align = NULL, id = NULL)),
                         column = list(required = "children",
                                       optional = list(gap = NULL, id = NULL)),
                         panel = list(required = "children",
                                      optional = list(variant = "plain", title = NULL, id = NULL)),

                         # escape hatch
                         raw_html = list(required = "html", optional = list())
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

    missing <- setdiff(schema$required, names(fields))
    if (length(missing) > 0L) {
        stop(type, "() is missing required field(s): ",
             paste(missing, collapse = ", "), call. = FALSE)
    }

    allowed <- c(schema$required, names(schema$optional))
    extra <- setdiff(names(fields), allowed)
    if (length(extra) > 0L) {
        stop(type, "() got unknown field(s): ",
             paste(extra, collapse = ", "),
             ". Allowed: ", paste(allowed, collapse = ", "), call. = FALSE)
    }

    # An absent optional field is absent on the wire, not null. Only
    # defaults that are themselves non-NULL get filled in.
    for (nm in names(schema$optional)) {
        default <- schema$optional[[nm]]
        if (is.null(fields[[nm]]) && !is.null(default)) {
            fields[[nm]] <- default
        }
    }
    fields <- fields[!vapply(fields, is.null, logical(1L))]

    structure(c(list(component = type), fields), class = "glinty_component")
}

#' Is this a component?
#'
#' @param x any object
#' @return logical
#' @keywords internal
is_component <- function(x) {
    inherits(x, "glinty_component")
}

#' Coerce a list of children, rejecting anything that is not a component
#'
#' Layout components accept `...` and every element has to be a
#' component, or a lowering will meet something it cannot render at the
#' worst possible moment. Catching it here names the caller instead.
#'
#' @param children list of candidate children
#' @param fn character calling function, for the error message
#' @return the list, unnamed
#' @keywords internal
check_children <- function(children, fn) {
    children <- Filter(Negate(is.null), children)
    ok <- vapply(children, is_component, logical(1L))
    if (!all(ok)) {
        bad <- which(!ok)[[1L]]
        stop(fn, "() child ", bad, " is not a component (got ",
             paste(class(children[[bad]]), collapse = "/"), "). ",
             "Wrap plain strings in text().", call. = FALSE)
    }
    unname(children)
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
