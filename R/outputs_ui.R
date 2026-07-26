#' Create a text output placeholder
#'
#' @param id character output ID
#' @return A UI element
#' @examples
#' text_output("greeting")
#' @export
text_output <- function(id) {
    tag("span", attrs = list(id = id, class = "g-output"))
}

#' Create an HTML output placeholder
#'
#' Unlike text_output, the output value is set as innerHTML rather
#' than textContent. Use with render_html() for markup from R.
#'
#' @param id character output ID
#' @return A UI element
#' @examples
#' html_output("details")
#' @export
html_output <- function(id) {
    tag("div", attrs = list(id = id, class = "g-html-output"))
}

#' Create a preformatted text output placeholder
#'
#' A pre element patched on textContent, so whitespace and line
#' breaks survive and the value is always displayed literally. Pair
#' with render_text() for console-style output such as str() dumps or
#' captured messages.
#'
#' @param id character output ID
#' @return A UI element
#' @examples
#' verbatim_output("raw")
#' @export
verbatim_output <- function(id) {
    tag("pre", attrs = list(id = id, class = "g-verbatim-output"))
}

#' Create a table output placeholder
#'
#' @param id character output ID
#' @return A UI element
#' @examples
#' table_output("results")
#' @export
table_output <- function(id) {
    tag("div", attrs = list(id = id, class = "g-table-output"))
}

#' Create a plot output placeholder
#'
#' An img element whose src is set to a PNG data URI by
#' render_plot(). With NULL width/height (the default) the element
#' fills its container at a 4:3 aspect ratio and the client reports
#' its rendered size, so render_plot(NULL, NULL) draws at the true
#' on-screen dimensions. Explicit dimensions give a fixed-size box;
#' match them to the renderer's.
#'
#' @param id character output ID
#' @param width integer pixel width, or NULL for responsive
#' @param height integer pixel height, or NULL for responsive
#' @return A UI element
#' @examples
#' plot_output("scatter")
#' @export
plot_output <- function(id, width = NULL, height = NULL) {
    attrs <- list(id = id, class = "g-plot-output", alt = "")
    if (is.null(width) && is.null(height)) {
        attrs$style <- "width:100%;aspect-ratio:4 / 3;"
    } else {
        if (!is.null(width)) {
            attrs$width <- as.character(width)
        }
        if (!is.null(height)) {
            attrs$height <- as.character(height)
        }
    }
    tag("img", attrs = attrs)
}

#' Create an audio output element
#'
#' The output renderer should set the src property to a data URI
#' or URL, e.g. with render_audio().
#'
#' @param id character output ID
#' @return A UI element
#' @examples
#' audio_output("player")
#' @export
audio_output <- function(id) {
    tag("audio",
        attrs = list(id = id, controls = "controls", class = "g-audio-output"))
}

#' Create a dynamic UI output placeholder
#'
#' The container for render_ui(): server-built tag trees replace its
#' contents at runtime, on both the browser and native frontends.
#'
#' @param id character output ID
#' @return A UI element
#' @examples
#' ui_output("panel")
#' @export
ui_output <- function(id) {
    tag("div", attrs = list(id = id, class = "g-ui-output"))
}
