#' Wrap rendered HTML in a full page
#'
#' Emits the document shell: the server-rendered UI inside
#' #glinty-root, the package stylesheet, and the JS client. Package
#' assets are served under /glinty/; app-local files under /static/.
#'
#' @param body_html character HTML for the page body
#' @param title character page title
#' @return character complete HTML document
#' @keywords internal
full_page_html <- function(body_html, title = "glinty app") {
    paste0(
        "<!DOCTYPE html>\n<html>\n<head>\n",
        "<meta charset=\"utf-8\">\n",
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
        "<title>", html_escape(title), "</title>\n",
        "<link rel=\"stylesheet\" href=\"/glinty/glinty.css\">\n",
        "</head>\n<body>\n",
        "<div id=\"glinty-root\">", body_html, "</div>\n",
        "<script src=\"/glinty/glinty.js\"></script>\n",
        "</body>\n</html>"
    )
}
