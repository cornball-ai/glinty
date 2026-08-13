# Output builders. An output is a slot: it names an id and says how to
# present whatever arrives for it. None carry a value, because what
# the value *is* comes from the renderer, as `kind` on the output
# message.

#' Create a text output slot
#'
#' @param id character output ID
#' @param variant character "normal", "muted", "strong", "mono" or
#'   "small". "mono" is for values that align by character: timecodes,
#'   file listings, hashes. "small" is fine print
#' @return A UI component
#' @examples
#' text_output("greeting")
#' @export
text_output <- function(id, variant = "normal") {
    component("text_output", id = id, variant = variant)
}

#' Create a preformatted text output slot
#'
#' Whitespace and line breaks survive, and the value is always shown
#' literally. Pair with render_text() for console-style output such as
#' str() dumps or captured messages.
#'
#' @param id character output ID
#' @return A UI component
#' @examples
#' verbatim_output("raw")
#' @export
verbatim_output <- function(id) {
    component("verbatim_output", id = id)
}

#' Create a table output slot
#'
#' The value travels as structure -- header plus rows -- rather than
#' markup, so each frontend draws it natively.
#'
#' @param id character output ID
#' @return A UI component
#' @examples
#' table_output("results")
#' @export
table_output <- function(id) {
    component("table_output", id = id)
}

#' Create a plot output slot
#'
#' With NULL dimensions the slot fills its container and the client
#' reports its rendered box back, so render_plot() can draw at the true
#' on-screen size. Explicit dimensions give a fixed box, which is what
#' a client that cannot measure itself needs.
#'
#' @param id character output ID
#' @param width,height integer pixel size, or NULL for client-sized
#' @param alt character alternative text
#' @return A UI component
#' @examples
#' plot_output("scatter")
#' plot_output("fixed", width = 400L, height = 300L)
#' @export
plot_output <- function(id, width = NULL, height = NULL, alt = "") {
    component("plot_output", id = id, width = width, height = height, alt = alt)
}

#' Create an image output slot
#'
#' @param id character output ID
#' @param alt character alternative text
#' @return A UI component
#' @examples
#' image_output("preview")
#' @export
image_output <- function(id, alt = "") {
    component("image_output", id = id, alt = alt)
}

#' Create an audio output slot
#'
#' @param id character output ID
#' @param controls logical show transport controls
#' @param autoplay logical begin playing on arrival
#' @return A UI component
#' @examples
#' audio_output("player")
#' @export
audio_output <- function(id, controls = TRUE, autoplay = FALSE) {
    component("audio_output", id = id, controls = controls, autoplay = autoplay)
}

#' Create a dynamic UI slot
#'
#' The container for render_ui(): server-built component trees replace
#' its contents at runtime. Inputs that first appear inside dynamic UI
#' start as NULL server-side until the user touches them.
#'
#' @param id character output ID
#' @return A UI component
#' @examples
#' ui_output("panel")
#' @export
ui_output <- function(id) {
    component("ui_output", id = id)
}

#' Create a raw HTML output slot
#'
#' Browser-only, like tag(). The value is inserted as markup, so any
#' other frontend refuses it by name. Prefer ui_output() with
#' render_ui() for anything that must render on more than one client.
#'
#' @param id character output ID
#' @return A UI component
#' @examples
#' html_output("details")
#' @export
html_output <- function(id) {
    component("html_output", id = id)
}
