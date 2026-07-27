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

#' Emit trusted raw HTML
#'
#' The browser-only escape hatch, for markup with no component
#' equivalent.
#'
#' **The string is inserted into the page unescaped.** It is trusted
#' HTML, not text: markup in it is markup, and a `<script>` in it
#' runs. So the argument must be a literal you wrote, or built from
#' parts you control. Never interpolate a user-supplied string, a
#' request parameter, a filename, a database field or a model
#' response into it. That is cross-site scripting, and glinty does
#' nothing to stop it here by design -- escaping the string would
#' defeat the only purpose the function has.
#'
#' For text of any provenance, use \code{\link{txt}()}, which travels
#' as a value and is escaped by whichever frontend renders it. If you
#' genuinely need markup around untrusted text, run the text through
#' \code{\link{html_escape}()} before pasting it in.
#'
#' Any frontend other than the browser refuses it by name and draws a
#' visible placeholder, since arbitrary markup cannot be translated
#' into a widget tree. Content that has to appear everywhere belongs
#' in the component set instead.
#'
#' @param html character trusted raw HTML
#' @return A UI component
#' @seealso \code{\link{txt}} for untrusted text,
#'   \code{\link{html_escape}} to escape it
#' @examples
#' tag("<details><summary>More</summary>body</details>")
#'
#' # untrusted text needs escaping first
#' name <- "<script>alert(1)</script>"
#' tag(paste0("<figcaption>", html_escape(name), "</figcaption>"))
#' @export
tag <- function(html) {
    component("raw_html", html = html)
}

#' Escape text for safe HTML output
#'
#' Only needed when building a string for \code{\link{tag}()}. Text
#' carried by a component is escaped by the frontend that renders it,
#' so escaping it here would double-escape and show the entities.
#'
#' @param x character string
#' @return character with &, <, >, " escaped
#' @seealso \code{\link{tag}}
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
