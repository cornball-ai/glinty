#' Wrap rendered HTML in a full page
#'
#' Emits the document shell: the server-rendered UI inside
#' #glinty-root, the package stylesheet, and the JS client. Package
#' assets are served under /glinty/; app-local files under /static/.
#'
#' App stylesheets land after glinty.css so they win on equal
#' specificity. App scripts land after glinty.js at the end of the
#' body, so window.Glinty already exists when they run.
#'
#' @param body_html character HTML for the page body
#' @param title character page title
#' @param head a page head spec (see page_head()), or NULL
#' @param ui_revision character revision of the tree body_html was
#'   rendered from, embedded as a meta tag so the client can tell
#'   whether this markup describes the tree welcome sends it; NULL
#'   omits the tag (a client without one rebuilds from welcome)
#' @return character complete HTML document
#' @keywords internal
full_page_html <- function(body_html, title = "glinty app", head = NULL,
                           ui_revision = NULL) {
    revision_meta <- if (is.null(ui_revision)) {
        ""
    } else {
        paste0("<meta name=\"g-ui-revision\" content=\"",
               html_escape(ui_revision), "\">\n")
    }
    paste0(
           "<!DOCTYPE html>\n<html>\n<head>\n",
           "<meta charset=\"utf-8\">\n",
           "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
           revision_meta,
           "<title>", html_escape(title), "</title>\n",
           "<link rel=\"stylesheet\" href=\"/glinty/glinty.css\">\n",
           head_html(head),
           "</head>\n<body>\n",
           "<div id=\"glinty-root\">", body_html, "</div>\n",
           "<script src=\"/glinty/glinty.js\"></script>\n",
           body_scripts_html(head),
           "</body>\n</html>"
    )
}

#' Build a page head spec
#'
#' Normalizes page()'s asset arguments into the list carried on the
#' UI tree and consumed by full_page_html().
#'
#' @param css character vector of stylesheet URLs
#' @param js character vector of script URLs
#' @param favicon character icon URL
#' @param extra raw character HTML appended to head
#' @return a list, or NULL when nothing was supplied
#' @keywords internal
page_head <- function(css = NULL, js = NULL, favicon = NULL, extra = NULL) {
    if (is.null(css) && is.null(js) && is.null(favicon) && is.null(extra)) {
        return(NULL)
    }
    list(css = css, js = js, favicon = favicon, extra = extra)
}

#' Render the head additions for a page
#'
#' @param head a page head spec, or NULL
#' @return character HTML (empty string when there is nothing to add)
#' @keywords internal
head_html <- function(head) {
    if (is.null(head)) {
        return("")
    }
    parts <- character(0L)
    if (!is.null(head$favicon)) {
        parts <- c(parts, paste0("<link rel=\"icon\" href=\"",
                                 html_escape(head$favicon), "\">\n"))
    }
    for (href in head$css) {
        parts <- c(parts, paste0("<link rel=\"stylesheet\" href=\"",
                                 html_escape(href), "\">\n"))
    }
    parts <- c(parts, raw_head_html(head$extra))
    paste(parts, collapse = "")
}

#' Render app scripts for the end of the body
#'
#' @param head a page head spec, or NULL
#' @return character HTML (empty string when there are no scripts)
#' @keywords internal
body_scripts_html <- function(head) {
    if (is.null(head) || length(head$js) == 0L) {
        return("")
    }
    paste(paste0("<script src=\"", html_escape(head$js), "\"></script>\n"),
          collapse = "")
}

#' Serialize the escape-hatch head content
#'
#' Trusted as-is, since the
#' whole point of the escape hatch is emitting markup glinty has no
#' constructor for.
#'
#' @param extra character, or NULL
#' @return character HTML
#' @keywords internal
raw_head_html <- function(extra) {
    if (is.null(extra)) {
        return(character(0L))
    }
    if (is.character(extra)) {
        return(paste0(paste(extra, collapse = "\n"), "\n"))
    }
    stop("page(head=) expects character or NULL", call. = FALSE)
}
