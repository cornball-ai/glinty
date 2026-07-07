#' Construct a renderer
#'
#' @param fn zero-arg function producing the client-ready value
#' @param property character DOM property the value patches
#' @return a glinty_renderer
#' @keywords internal
new_renderer <- function(fn, property) {
    structure(list(fn = fn, property = property), class = "glinty_renderer")
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
    new_renderer(function() paste(as.character(fn()), collapse = " "),
                 "textContent")
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
    head_cells <- paste0("<th>", html_escape(names(df)), "</th>", collapse = "")
    rows <- vapply(seq_len(nrow(df)), function(i) {
        cells <- vapply(cols, function(col) {
            paste0("<td>", html_escape(col[[i]]), "</td>")
        }, character(1L))
        paste0("<tr>", paste(cells, collapse = ""), "</tr>")
    }, character(1L))
    paste0('<table class="g-table"><thead><tr>', head_cells,
           "</tr></thead><tbody>", paste(rows, collapse = ""),
           "</tbody></table>")
}

#' Render a base graphics plot
#'
#' Runs the plotting function against a PNG device and patches the
#' output img's src with a data URI. With NULL width/height (the
#' default) the plot sizes itself to the client: the browser reports
#' the rendered img box as reserved inputs and re-reports on window
#' resize, so the plot re-renders reactively at the new size.
#' Explicit numeric dimensions give fixed-size rendering.
#'
#' @param fn zero-arg function that draws a plot
#' @param width integer pixel width, or NULL for client-driven
#' @param height integer pixel height, or NULL for client-driven
#' @param res numeric PNG resolution (dpi)
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$scatter <- render_plot(function() plot(rnorm(100)))
#' }
#' @export
render_plot <- function(fn, width = NULL, height = NULL, res = 72) {
    if (!capabilities("png")) {
        stop("render_plot() requires PNG support in this R build",
             call. = FALSE)
    }
    make_fn <- function(id, session) {
        function() {
            w <- if (is.null(width)) {
                client_dim(session, id, "width", fallback = 480)
            } else {
                width
            }
            h <- if (is.null(height)) {
                client_dim(session, id, "height", fallback = 360)
            } else {
                height
            }
            tmp <- tempfile(fileext = ".png")
            on.exit(unlink(tmp), add = TRUE)
            grDevices::png(tmp, width = w, height = h, res = res)
            tryCatch(fn(), finally = grDevices::dev.off())
            bytes <- readBin(tmp, "raw", file.info(tmp)$size)
            uri <- paste0("data:image/png;base64,", jsonlite::base64_enc(bytes))
            gsub("[\r\n]", "", uri)
        }
    }
    structure(list(bind = make_fn, property = "src"), class = "glinty_renderer")
}

#' Read a client-reported output dimension
#'
#' The JS client reports each plot output's rendered box as reserved
#' inputs ..clientdata_output_<id>_width/_height (at init and on
#' window resize). Reading them here is a tracked reactive read, so
#' a resize re-renders the plot.
#'
#' @param session a glinty_session
#' @param id character output ID
#' @param dim character "width" or "height"
#' @param fallback numeric size before the client has reported
#' @return numeric pixel dimension
#' @keywords internal
client_dim <- function(session, id, dim, fallback) {
    key <- paste0("..clientdata_output_", id, "_", dim)
    val <- session$input[[key]]()
    val <- suppressWarnings(as.numeric(val))
    if (length(val) != 1L || !is.finite(val) || val < 1) {
        return(fallback)
    }
    val
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
