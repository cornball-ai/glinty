#' Generic tag constructor
#'
#' The extensibility contract: any element with an id, a
#' data-g-event, and a data-g-target (via bind) is a glinty input;
#' any element with an id can be an output target. Custom widgets are
#' plain R functions returning tag() trees.
#'
#' @param name character tag name (e.g. "div", "button")
#' @param children list of child tags
#' @param text character text content (takes precedence over children)
#' @param attrs named list of HTML attributes
#' @param bind list with event and target fields for JS event binding
#' @return A tag list with class "glinty_tag"
#' @examples
#' tag("input",
#'     attrs = list(id = "col", type = "color"),
#'     bind = list(event = "input", target = "col"))
#' @export
tag <- function(name, children = list(), text = NULL, attrs = list(),
                bind = NULL) {
    structure(
              list(
                   tag = name, attrs = attrs, text = text,
                   children = children, bind = bind
        ),
              class = "glinty_tag"
    )
}

#' Escape text for safe HTML output
#'
#' @param x character string
#' @return character with &, <, >, " escaped
#' @examples
#' html_escape("a <b> & \"c\"")
#' @export
html_escape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub('"', "&quot;", x, fixed = TRUE)
    x
}

#' Convert a tag tree to an HTML string
#'
#' @param x a glinty_tag object or character
#' @return character HTML string
#' @keywords internal
tag_to_html <- function(x) {
    if (is.null(x)) return("")
    if (is.character(x)) return(html_escape(x))

    void <- c("input", "br", "hr", "img", "meta", "link")
    name <- x$tag

    # Build attribute string
    attr_parts <- character(0)
    if (length(x$attrs) > 0) {
        for (nm in names(x$attrs)) {
            attr_parts <- c(
                attr_parts,
                paste0(nm, '="', html_escape(as.character(x$attrs[[nm]])), '"')
            )
        }
    }

    # Add data attributes for event binding
    if (!is.null(x$bind)) {
        attr_parts <- c(
            attr_parts,
            paste0('data-g-event="', x$bind$event, '"'),
            paste0('data-g-target="', x$bind$target, '"')
        )
    }

    attr_str <- if (length(attr_parts) > 0) {
        paste0(" ", paste(attr_parts, collapse = " "))
    } else {
        ""
    }

    if (name %in% void) {
        return(paste0("<", name, attr_str, ">"))
    }

    # Text takes precedence over children
    inner <- ""
    if (!is.null(x$text)) {
        inner <- html_escape(x$text)
    } else if (length(x$children) > 0) {
        inner <- paste(
            vapply(x$children, tag_to_html, character(1)),
            collapse = ""
        )
    }

    paste0("<", name, attr_str, ">", inner, "</", name, ">")
}

#' Print a tag as HTML
#'
#' @param x a glinty_tag
#' @param ... ignored
#' @return x, invisibly
#' @examples
#' print(h1("Hello"))
#' @export
print.glinty_tag <- function(x, ...) {
    cat(tag_to_html(x), "\n")
    invisible(x)
}
