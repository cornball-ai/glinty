# Output builders. An output is a slot: it names an id and says how to
# present whatever arrives for it. None carry a value, because what
# the value *is* comes from the renderer, as `kind` on the output
# message.

#' Create a text output slot
#'
#' @param id character output ID
#' @param variant character "normal", "muted", "strong", "heading",
#'   "mono", "small", "success", "warning" or "danger". "mono" is for
#'   values that align by character: timecodes, file listings, hashes.
#'   "small" is fine print. The status trio colors the value from the
#'   theme's semantic tokens -- the live health readout shape
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

#' Create an interactive table output slot
#'
#' Takes the same table value as [table_output()] -- header, rows,
#' alignment -- and adds client-side sorting, filtering and
#' pagination. Interaction never touches the server: the client
#' holds the whole value and rearranges it locally, so sort state
#' lives where the click happened and a re-rendered value keeps the
#' reader's page when it still exists. Numeric columns (the
#' alignment the wire already carries) sort numerically; the rest
#' sort as text. Feed it with [render_table()] like any table; keep
#' the value at a size a client comfortably holds -- sample or
#' pre-filter server-side above a few thousand rows.
#'
#' Given a `selection`, the table is also an input: `input[[id]]` is
#' the character vector of selected row keys -- the data.frame's
#' `row.names()`, which [render_table()] sends as `keys` -- and
#' `character(0)` when nothing is selected, so `df[input$grid(), ]`
#' is the selected rows. `"single"` replaces the selection on each
#' click and clears it on a second click of the same row;
#' `"multiple"` toggles rows. Keys are reported in data order, not
#' click order, and a row that leaves the value leaves the selection.
#' Sorting and filtering stay local, so a selected row stays selected
#' through both.
#'
#' @param id character output ID
#' @param page_length integer rows shown per page
#' @param length_menu numeric page-size options offered
#' @param searchable logical show the filter box
#' @param sortable logical allow header-click sorting
#' @param selection character "none", "single" or "multiple": whether
#'   rows can be selected, and how many at once
#' @return A UI component
#' @examples
#' data_table("results", page_length = 5)
#' data_table("runs", selection = "single")
#' @export
data_table <- function(id, page_length = 10L,
                       length_menu = c(10, 25, 50, 100), searchable = TRUE,
                       sortable = TRUE, selection = "none") {
    component("data_table", id = id, page_length = page_length,
              length_menu = length_menu, searchable = searchable,
              sortable = sortable, selection = selection)
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

#' Create a video output slot
#'
#' Pair with [render_video()]. The value's src wants to be a real URL
#' -- a `/static/` path the app serves -- rather than embedded bytes:
#' seeking works by byte-range requests against a URL, and a data URI
#' has no ranges to ask for.
#'
#' The element fills its container's width on a dark letterbox and
#' keeps the video's own aspect. Playback can also be driven from the
#' server with [update_video()].
#'
#' With `report = TRUE` the player also reports back: `input[[id]]`
#' holds `list(current_time =, playing =)`, throttled while playing
#' and immediate on play, pause and seek, so an external playhead (a
#' timeline, a transport slider) can follow the player the same way
#' [update_video()] lets the player follow it. A position the server
#' just set does not bounce back as a fresh report. Opt-in, because
#' most videos never need to phone home.
#'
#' @param id character output ID
#' @param controls logical show the player's transport controls
#' @param autoplay logical begin playing on arrival. Browsers block
#'   autoplay with sound, so autoplay wants `muted = TRUE`
#' @param muted logical start muted
#' @param loop logical start over at the end
#' @param report logical report position and playing state to the
#'   server through `input[[id]]`
#' @return A UI component
#' @examples
#' video_output("preview")
#' video_output("preview", report = TRUE)
#' @export
video_output <- function(id, controls = TRUE, autoplay = FALSE,
                         muted = FALSE, loop = FALSE, report = FALSE) {
    component("video_output", id = id, controls = controls,
              autoplay = autoplay, muted = muted, loop = loop,
              report = report)
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
