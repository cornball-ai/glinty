# The escape hatch.
#
# Under protocol v2 tag() was how every widget was built. Under v3 the
# component set is, and tag() is what remains for markup glinty has no
# component for. It produces raw_html, which the browser renders and
# every other frontend refuses by name -- arbitrary HTML has no
# meaning to a Flutter widget tree.
#
# So anything that must render on more than one frontend comes from
# the component set, and this is for the browser-only remainder.

#' Emit raw HTML
#'
#' The browser-only escape hatch, for markup with no component
#' equivalent. The string is trusted as-is and inserted unescaped, so
#' never pass untrusted text through it.
#'
#' Any frontend other than the browser refuses it by name and draws a
#' visible placeholder, since arbitrary markup cannot be translated
#' into a widget tree. Content that has to appear everywhere belongs
#' in the component set instead.
#'
#' @param html character raw HTML
#' @return A UI component
#' @examples
#' tag("<details><summary>More</summary>body</details>")
#' @export
tag <- function(html) {
    component("raw_html", html = html)
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
