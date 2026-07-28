#' Construct a renderer
#'
#' @param fn zero-arg function producing the client-ready value
#' @param kind character what the value is (text, html, table, image,
#'   audio, ui) -- the `kind` field of the output message it feeds
#' @return a glinty_renderer
#' @keywords internal
new_renderer <- function(fn, kind) {
    structure(list(fn = fn, kind = kind), class = "glinty_renderer")
}

#' Render plain text
#'
#' The value travels as a string and every frontend displays it
#' literally (no HTML injection).
#'
#' @param fn zero-arg function computing the value
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$greeting <- render_text(function() paste("hello", input$name()))
#' }
#' @export
render_text <- function(fn) {
    new_renderer(function() paste(as.character(fn()), collapse = " "), "text")
}

#' Render HTML markup
#'
#' Browser-only: the value is markup the browser inserts as-is.
#' Component trees are serialized; character values are trusted, so
#' escape untrusted text with html_escape().
#'
#' @param fn zero-arg function returning a component or character
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$details <- render_html(function() "<mark>done</mark>")
#' }
#' @export
render_html <- function(fn) {
    new_renderer(
                 function() {
        val <- fn()
        if (is_component(val)) {
            component_to_html(val)
        } else {
            paste(as.character(val), collapse = "")
        }
    },
                 "html"
    )
}

#' Render a data frame as a table
#'
#' The wire carries structure (header + rows of strings), not markup:
#' the browser client builds the table via DOM (textContent per cell,
#' so escaping is structurally unnecessary) and the native frontend
#' draws a grid from the same data.
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
        df_to_table(df)
    },
                 "table"
    )
}

#' Convert a data.frame to the wire table structure
#'
#' I() wrappers keep length-1 headers and single-cell rows as JSON
#' arrays under auto_unbox.
#'
#' @param df a data.frame
#' @return list(header, rows) of character vectors
#' @keywords internal
df_to_table <- function(df) {
    cols <- lapply(df, function(col) {
        if (is.numeric(col)) format(col, trim = TRUE) else as.character(col)
    })
    rows <- lapply(seq_len(nrow(df)), function(i) {
        I(vapply(cols, function(col) col[[i]], character(1L),
                 USE.NAMES = FALSE))
    })
    list(header = I(names(df)), rows = rows)
}

#' Render a base graphics plot
#'
#' Runs the plotting function against a PNG device and sends an
#' `image` output: `{src, width, height}`, dimensions in logical
#' pixels. With NULL width/height (the default) the plot sizes itself
#' to the client, which reports its box through `measure` messages on
#' first layout and on resize; the read is reactive, so a new
#' measurement re-renders the plot. Explicit numeric dimensions give
#' fixed-size rendering.
#'
#' The client also reports its device pixel ratio, which applies to
#' fixed-size plots too. The raster is produced at `width * dpr` by
#' `height * dpr` physical pixels with `res` scaled by the same
#' factor, and displayed at the logical size: text and lines keep
#' their size while the pixels match the screen, which is what keeps
#' a plot sharp on a 2x display.
#'
#' @param fn zero-arg function that draws a plot
#' @param width integer logical-pixel width, or NULL for client-driven
#' @param height integer logical-pixel height, or NULL for
#'   client-driven
#' @param res numeric PNG resolution (dpi) at dpr 1
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
            # Reading the box is the reactive subscription that makes a
            # new measurement re-render. Every plot reads it: a plot
            # with explicit dimensions ignores the measured size, but
            # still needs the device pixel ratio, which only the
            # client knows -- without it, fixed-size plots would stay
            # blurry on dense displays. Its box cannot otherwise
            # change, so the subscription only ever fires for real.
            box <- measured_box(session, id)
            w <- if (is.null(width)) {
                if (is.null(box)) {
                    480
                } else {
                    box$width
                }
            } else {
                width
            }
            h <- if (is.null(height)) {
                if (is.null(box)) {
                    360
                } else {
                    box$height
                }
            } else {
                height
            }
            if (is.null(box)) {
                dpr <- 1
            } else {
                dpr <- box$dpr
            }
            tmp <- tempfile(fileext = ".png")
            on.exit(unlink(tmp), add = TRUE)
            grDevices::png(tmp, width = w * dpr, height = h * dpr,
                           res = res * dpr)
            tryCatch(fn(), finally = grDevices::dev.off())
            bytes <- readBin(tmp, "raw", file.info(tmp)$size)
            uri <- paste0("data:image/png;base64,", jsonlite::base64_enc(bytes))
            list(src = gsub("[\r\n]", "", uri), width = w, height = h)
        }
    }
    structure(list(bind = make_fn, kind = "image"), class = "glinty_renderer")
}

#' Render an audio source
#'
#' Sends an `audio` output: `{src, mime, duration?}`, where src is a
#' data URI or a /static/ path.
#'
#' `mime` is not optional. A browser sniffs the bytes and does not
#' need it, which is why it went missing for so long; a native client
#' has to hand the source to a platform player that asks what it is.
#' So fn may return the src alone and let this read the type out of
#' the data URI or off the file extension -- neither is a guess, both
#' are stated in the string -- or return a list to say outright:
#'
#' \preformatted{
#' render_audio(function() list(src = uri, mime = "audio/wav",
#'                              duration = 12.5))
#' }
#'
#' An extension this does not know is an error naming the fix rather
#' than a value invented to fill the field.
#'
#' @param fn zero-arg function returning the source string, or a list
#'   with `src` and optionally `mime` and `duration` (seconds)
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$player <- render_audio(function() "/static/chime.wav")
#' }
#' @export
render_audio <- function(fn) {
    new_renderer(function() {
        v <- fn()
        if (is.null(v)) {
            return(NULL)
        }
        if (!is.list(v)) {
            v <- list(src = v)
        }
        src <- as.character(v$src)
        mime <- if (is.null(v$mime)) audio_mime(src) else as.character(v$mime)
        out <- list(src = src, mime = mime)
        if (!is.null(v$duration)) {
            out$duration <- as.numeric(v$duration)
        }
        out
    }, "audio")
}

# Media types glinty can name without being told. Every format a
# browser plays, which is the set an app can reasonably hand over.
AUDIO_MIME <- c(wav = "audio/wav", wave = "audio/wav", mp3 = "audio/mpeg",
                ogg = "audio/ogg", oga = "audio/ogg", opus = "audio/ogg",
                m4a = "audio/mp4", mp4 = "audio/mp4", aac = "audio/aac",
                flac = "audio/flac", webm = "audio/webm")

#' The media type of an audio source
#'
#' Read out of the source rather than guessed at: a data URI declares
#' its own type, and a path's extension is the only thing anyone has
#' to go on. Neither is inference -- both are written in the string.
#'
#' @param src character data URI or path
#' @return character media type
#' @keywords internal
audio_mime <- function(src) {
    if (grepl("^data:", src)) {
        declared <- sub("^data:([^;,]+).*$", "\\1", src)
        if (nzchar(declared) && !identical(declared, src)) {
            return(declared)
        }
        stop("audio data URI declares no media type; pass mime = ",
             call. = FALSE)
    }
    ext <- tolower(tools::file_ext(sub("[?#].*$", "", src)))
    if (!ext %in% names(AUDIO_MIME)) {
        stop("cannot name the media type of \"", src,
             "\"; return list(src = , mime = ) instead", call. = FALSE)
    }
    unname(AUDIO_MIME[[ext]])
}

#' Render a dynamic UI subtree
#'
#' The portable path for dynamic content: fn returns a component
#' (wrap several in column() or row()) or NULL to render nothing. The
#' component tree travels structured on the wire, so every frontend
#' builds it the way it builds static UI -- the browser as real DOM,
#' event bindings included via delegation. Inputs that first appear
#' inside dynamic UI start as NULL server-side until the user touches
#' them. For raw markup strings use render_html(), which is a
#' browser-only escape hatch.
#'
#' @param fn zero-arg function returning a component or NULL
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$panel <- render_ui(function() {
#'     if (isTRUE(input$show())) column(text_input("extra", "Extra:"))
#' })
#' }
#' @export
render_ui <- function(fn) {
    new_renderer(
                 function() {
        val <- fn()
        if (is.null(val)) {
            return(NULL)
        }
        if (!is_component(val)) {
            stop("render_ui() expects a component or NULL; wrap ",
                 "several in column()", call. = FALSE)
        }
        unclass_recursive(val)
    },
                 "ui"
    )
}
