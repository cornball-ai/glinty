#' Create an HTML page
#'
#' The top-level UI container. The title becomes the browser tab
#' title when the page is served.
#'
#' @param ... child elements
#' @param title character page title
#' @return A UI tree (glinty_tag with a title field)
#' @examples
#' page(h1("Hello"), title = "My app")
#' @export
page <- function(..., title = "glinty app") {
    ui <- tag("div", children = list(...), attrs = list(class = "g-page"))
    ui$title <- title
    ui
}

#' Create a generic container
#'
#' @param ... child elements
#' @param class character CSS class(es)
#' @param id character element ID
#' @return A UI element
#' @examples
#' div(h2("Section"), class = "sidebar")
#' @export
div <- function(..., class = NULL, id = NULL) {
    attrs <- list()
    if (!is.null(class)) attrs$class <- class
    if (!is.null(id)) attrs$id <- id
    tag("div", children = list(...), attrs = attrs)
}

#' Create a generic inline element
#'
#' @param ... child elements or text
#' @param class character CSS class(es)
#' @param id character element ID
#' @return A UI element
#' @examples
#' span("status: ok", class = "muted")
#' @export
span <- function(..., class = NULL, id = NULL) {
    children <- list(...)
    text <- NULL
    if (length(children) == 1L && is.character(children[[1L]])) {
        text <- children[[1L]]
        children <- list()
    }
    attrs <- list()
    if (!is.null(class)) attrs$class <- class
    if (!is.null(id)) attrs$id <- id
    tag("span", children = children, text = text, attrs = attrs)
}

#' Create a paragraph
#'
#' @param ... child elements or text
#' @param class character CSS class(es)
#' @return A UI element
#' @examples
#' p("Some explanatory text.")
#' @export
p <- function(..., class = NULL) {
    children <- list(...)
    text <- NULL
    if (length(children) == 1L && is.character(children[[1L]])) {
        text <- children[[1L]]
        children <- list()
    }
    attrs <- list()
    if (!is.null(class)) attrs$class <- class
    tag("p", children = children, text = text, attrs = attrs)
}

#' Create a hyperlink
#'
#' @param text character link text
#' @param href character link target URL
#' @return A UI element
#' @examples
#' a("cornball.ai", "https://cornball.ai")
#' @export
a <- function(text, href) {
    tag("a", text = text, attrs = list(href = href))
}

#' Create a heading
#'
#' @param text character heading text
#' @return A UI element
#' @examples
#' h1("Title")
#' @export
h1 <- function(text) tag("h1", text = text)

#' Create a second-level heading
#'
#' @param text character heading text
#' @return A UI element
#' @examples
#' h2("Section")
#' @export
h2 <- function(text) tag("h2", text = text)

#' Create a third-level heading
#'
#' @param text character heading text
#' @return A UI element
#' @examples
#' h3("Subsection")
#' @export
h3 <- function(text) tag("h3", text = text)

#' Create a fourth-level heading
#'
#' @param text character heading text
#' @return A UI element
#' @examples
#' h4("Detail")
#' @export
h4 <- function(text) tag("h4", text = text)
