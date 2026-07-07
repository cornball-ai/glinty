#' Construct a renderer
#'
#' @param fn zero-arg function producing the client-ready value
#' @param property character DOM property the value patches
#' @return a glinty_renderer
#' @keywords internal
new_renderer <- function(fn, property) {
    structure(
        list(fn = fn, property = property),
        class = "glinty_renderer"
    )
}

#' Render plain text
#'
#' The value is coerced to character and set as textContent, so it
#' is always displayed literally (no HTML injection).
#'
#' @param fn zero-arg function computing the value
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$greeting <- render_text(function() paste("hello", input$name()))
#' }
#' @export
render_text <- function(fn) {
    new_renderer(
        function() paste(as.character(fn()), collapse = " "),
        "textContent"
    )
}

#' Render HTML markup
#'
#' The value is set as innerHTML. glinty_tag trees are serialized;
#' character values are trusted as-is, so escape untrusted text with
#' html_escape().
#'
#' @param fn zero-arg function returning a glinty_tag or character
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$details <- render_html(function() div(h3("Result"), p("done")))
#' }
#' @export
render_html <- function(fn) {
    new_renderer(
        function() {
            val <- fn()
            if (inherits(val, "glinty_tag")) {
                tag_to_html(val)
            } else {
                paste(as.character(val), collapse = "")
            }
        },
        "innerHTML"
    )
}

#' Render a data frame as an HTML table
#'
#' Cell contents are escaped.
#'
#' @param fn zero-arg function returning a data.frame
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$results <- render_table(function() head(mtcars))
#' }
#' @export
render_table <- function(fn) {
    new_renderer(
        function() {
            df <- fn()
            if (!is.data.frame(df)) {
                stop("render_table() expects a data.frame", call. = FALSE)
            }
            df_to_html(df)
        },
        "innerHTML"
    )
}

#' Serialize a data.frame to an escaped HTML table
#'
#' @param df a data.frame
#' @return character HTML
#' @keywords internal
df_to_html <- function(df) {
    cols <- lapply(df, function(col) {
        if (is.numeric(col)) format(col, trim = TRUE) else as.character(col)
    })
    head_cells <- paste0("<th>", html_escape(names(df)), "</th>",
        collapse = "")
    rows <- vapply(seq_len(nrow(df)), function(i) {
        cells <- vapply(cols, function(col) {
            paste0("<td>", html_escape(col[[i]]), "</td>")
        }, character(1L))
        paste0("<tr>", paste(cells, collapse = ""), "</tr>")
    }, character(1L))
    paste0(
        '<table class="g-table"><thead><tr>', head_cells,
        "</tr></thead><tbody>", paste(rows, collapse = ""),
        "</tbody></table>"
    )
}

#' Render a base graphics plot
#'
#' Runs the plotting function against a PNG device and patches the
#' output img's src with a data URI. Size is fixed at render time;
#' match it to plot_output()'s width and height.
#'
#' @param fn zero-arg function that draws a plot
#' @param width integer pixel width
#' @param height integer pixel height
#' @param res numeric PNG resolution (dpi)
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$scatter <- render_plot(function() plot(rnorm(100)))
#' }
#' @export
render_plot <- function(fn, width = 480, height = 360, res = 72) {
    if (!capabilities("png")) {
        stop("render_plot() requires PNG support in this R build",
            call. = FALSE)
    }
    new_renderer(
        function() {
            tmp <- tempfile(fileext = ".png")
            on.exit(unlink(tmp), add = TRUE)
            grDevices::png(tmp, width = width, height = height, res = res)
            tryCatch(fn(), finally = grDevices::dev.off())
            bytes <- readBin(tmp, "raw", file.info(tmp)$size)
            uri <- paste0("data:image/png;base64,",
                jsonlite::base64_enc(bytes))
            gsub("[\r\n]", "", uri)
        },
        "src"
    )
}

#' Render an audio source
#'
#' The value (a data URI or a /static/ path) is set as the audio
#' element's src.
#'
#' @param fn zero-arg function returning the source string
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$player <- render_audio(function() "/static/chime.wav")
#' }
#' @export
render_audio <- function(fn) {
    new_renderer(function() as.character(fn()), "src")
}
