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
#' than a value invented to fill the field. So is anything that would
#' not survive the wire as the scalar the protocol says it is: every
#' field here is one value, and a coercion that quietly turned a
#' two-element vector into a JSON array would put a shape on the wire
#' that no client can read.
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
        audio_value(v)
    }, "audio")
}

#' Check an audio value into the shape the protocol states
#'
#' Every field is a scalar, so every check here is the same check: one
#' value, present, and of the kind the field means. as.character() on
#' a two-element vector is a JSON array on a wire that promised a
#' string, and the client that meets it has no way to say what went
#' wrong -- the app does, here, where the mistake was made.
#'
#' @param v list with `src` and optionally `mime` and `duration`
#' @return list(src, mime, duration?)
#' @keywords internal
audio_value <- function(v) {
    src <- v$src
    if (!is.character(src) || length(src) != 1L || is.na(src) || !nzchar(src)) {
        stop("render_audio() needs one non-empty src string", call. = FALSE)
    }

    mime <- if (is.null(v$mime)) {
        audio_mime(src)
    } else {
        given <- v$mime
        if (!is.character(given) || length(given) != 1L || is.na(given)) {
            stop("render_audio() mime must be one media type string",
                 call. = FALSE)
        }
        given <- check_audio_mime(tolower(trimws(given)))
        # A data URI states its own type. Two answers to one question
        # is not something to pick a winner from: whichever this
        # honoured, the other half of the value would be a lie.
        declared <- data_uri_mime(src)
        if (!is.null(declared) && !identical(declared, given)) {
            stop("the audio data URI declares ", declared,
                 " and mime = says ", given, call. = FALSE)
        }
        given
    }

    out <- list(src = src, mime = mime)
    if (!is.null(v$duration)) {
        d <- v$duration
        if (!is.numeric(d) || length(d) != 1L || is.na(d) || !is.finite(d) ||
            d < 0) {
            stop("render_audio() duration must be one finite, non-negative ",
                 "number of seconds", call. = FALSE)
        }
        out$duration <- as.numeric(d)
    }
    out
}

#' Render a video source
#'
#' Sends a `video` output: `{src, mime, poster?, duration?}`. The
#' media-type discipline is [render_audio()]'s: fn may return the src
#' alone and let this read the type off the extension or out of a
#' data URI, or return a list to say outright -- and a type it cannot
#' read is an error naming the fix.
#'
#' The src wants to be a URL the client can fetch -- a `/static/`
#' path the app serves -- rather than embedded bytes. Seeking works
#' by byte-range requests against a URL, which glinty's static server
#' answers; a data URI has no ranges to ask for, so it plays but
#' cannot scrub. A server file path is therefore refused rather than
#' embedded: video is the one media size where a data URI on every
#' reactive tick stops being a convenience. Browsers cache by URL, so
#' a re-rendered cut wants a new file name, not the old one
#' rewritten.
#'
#' `poster` is the frame shown before play. An existing server file
#' is embedded as a data URI (it is one image, [render_image()]'s
#' deal); a URL passes through.
#'
#' @param fn zero-arg function returning the source string, or a list
#'   with `src` and optionally `mime`, `poster` and `duration`
#'   (seconds)
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$preview <- render_video(function() "/static/cut.mp4")
#' }
#' @export
render_video <- function(fn) {
    new_renderer(function() {
        v <- fn()
        if (is.null(v)) {
            return(NULL)
        }
        if (!is.list(v)) {
            v <- list(src = v)
        }
        video_value(v)
    }, "video")
}

#' Check a video value into the shape the protocol states
#'
#' audio_value()'s discipline, plus two of its own: a server file
#' path is refused rather than embedded (see [render_video()]), and a
#' poster naming a server file becomes a data URI here, where the
#' bytes are reachable.
#'
#' @param v list with `src` and optionally `mime`, `poster`,
#'   `duration`
#' @return list(src, mime, poster?, duration?)
#' @keywords internal
video_value <- function(v) {
    src <- v$src
    if (!is.character(src) || length(src) != 1L || is.na(src) || !nzchar(src)) {
        stop("render_video() needs one non-empty src string", call. = FALSE)
    }
    if (!grepl("^data:", src, ignore.case = TRUE) && file.exists(src)) {
        stop("render_video() does not embed server files: serve the ",
             "directory with run_app(static_dir = ) and return the file's ",
             "/static/ URL, so the client can seek by byte range",
             call. = FALSE)
    }

    mime <- if (is.null(v$mime)) {
        video_mime(src)
    } else {
        given <- v$mime
        if (!is.character(given) || length(given) != 1L || is.na(given)) {
            stop("render_video() mime must be one media type string",
                 call. = FALSE)
        }
        given <- check_video_mime(tolower(trimws(given)))
        declared <- data_uri_mime(src)
        if (!is.null(declared) && !identical(declared, given)) {
            stop("the video data URI declares ", declared,
                 " and mime = says ", given, call. = FALSE)
        }
        given
    }

    out <- list(src = src, mime = mime)
    if (!is.null(v$poster)) {
        p <- v$poster
        if (!is.character(p) || length(p) != 1L || is.na(p) || !nzchar(p)) {
            stop("render_video() poster must be one non-empty string",
                 call. = FALSE)
        }
        if (!startsWith(p, "data:") && file.exists(p)) {
            bytes <- readBin(p, "raw", file.info(p)$size)
            uri <- paste0("data:", image_mime(p), ";base64,",
                          jsonlite::base64_enc(bytes))
            p <- gsub("[\r\n]", "", uri)
        }
        out$poster <- p
    }
    if (!is.null(v$duration)) {
        d <- v$duration
        if (!is.numeric(d) || length(d) != 1L || is.na(d) || !is.finite(d) ||
            d < 0) {
            stop("render_video() duration must be one finite, non-negative ",
                 "number of seconds", call. = FALSE)
        }
        out$duration <- as.numeric(d)
    }
    out
}

VIDEO_MIME <- c(mp4 = "video/mp4", m4v = "video/mp4",
                mov = "video/quicktime", webm = "video/webm")

#' The media type of a video source
#'
#' audio_mime()'s rule: a data URI declares its own type, a path's
#' extension states one, and neither is a guess. Note the value's
#' webm is video/webm; serve_static() names the *file* audio/webm,
#' which is a different question (see mime_type()).
#'
#' @param src character data URI or path
#' @return character media type
#' @keywords internal
video_mime <- function(src) {
    if (grepl("^data:", src, ignore.case = TRUE)) {
        declared <- data_uri_mime(src)
        if (is.null(declared)) {
            stop("video data URI declares no media type; pass mime = ",
                 call. = FALSE)
        }
        return(check_video_mime(declared))
    }
    ext <- tolower(tools::file_ext(sub("[?#].*$", "", src)))
    if (!ext %in% names(VIDEO_MIME)) {
        stop("cannot name the media type of \"", src,
             "\"; return list(src = , mime = ) instead", call. = FALSE)
    }
    unname(VIDEO_MIME[[ext]])
}

#' Refuse a media type that is not video
#'
#' @param mime character lowercase media type
#' @return mime, invisibly refused by stop() when it is not video
#' @keywords internal
check_video_mime <- function(mime) {
    if (!grepl("^video/[!#$%&'*+.^_`|~0-9a-z-]+$", mime)) {
        stop("\"", mime, "\" is not a video media type", call. = FALSE)
    }
    mime
}

# Media types glinty can name without being told. Every format a
# browser plays, which is the set an app can reasonably hand over.
#' Render an image source
#'
#' Sends an `image` output: `{src, width?, height?}`, dimensions in
#' logical pixels when given. `fn` may return the source string alone
#' or a list to add dimensions.
#'
#' A source naming an existing file on the server is embedded as a
#' data URI -- a client cannot fetch server paths -- with the media
#' type read off the extension (an extension this does not know is an
#' error naming the fix, exactly as in [render_audio()]). Anything
#' else (`data:` URI, `/static/` path, http URL) already means
#' something to the client and passes through untouched.
#'
#' [render_plot()] draws base graphics into a fresh raster;
#' this renders images that already exist (thumbnails, exported
#' frames, generated stills).
#'
#' @param fn zero-arg function returning the source string, or a list
#'   with `src` and optionally `width` and `height` (logical pixels)
#' @return a glinty_renderer for assignment to output$id
#' @examples
#' \dontrun{
#' output$logo <- render_image(function() "/static/logo.png")
#' output$frame <- render_image(function() {
#'     list(src = exported_frame_path(), width = 320, height = 180)
#' })
#' }
#' @export
render_image <- function(fn) {
    new_renderer(function() {
        v <- fn()
        if (is.null(v)) {
            return(NULL)
        }
        if (!is.list(v)) {
            v <- list(src = v)
        }
        image_value(v)
    }, "image")
}

#' Check an image value into the shape the protocol states
#'
#' Same discipline as audio_value(): every field is one value of the
#' kind the field means, and a server file becomes a data URI here,
#' where the bytes are reachable.
#'
#' @param v list with `src` and optionally `width` and `height`
#' @return list(src, width?, height?)
#' @keywords internal
image_value <- function(v) {
    src <- v$src
    if (!is.character(src) || length(src) != 1L || is.na(src) || !nzchar(src)) {
        stop("render_image() needs one non-empty src string", call. = FALSE)
    }
    if (!startsWith(src, "data:") && file.exists(src)) {
        mime <- image_mime(src)
        bytes <- readBin(src, "raw", file.info(src)$size)
        uri <- paste0("data:", mime, ";base64,", jsonlite::base64_enc(bytes))
        src <- gsub("[\r\n]", "", uri)
    }
    out <- list(src = src)
    for (f in c("width", "height")) {
        d <- v[[f]]
        if (is.null(d)) {
            next
        }
        if (!is.numeric(d) || length(d) != 1L || is.na(d) || !is.finite(d) ||
            d <= 0) {
            stop("render_image() ", f, " must be one positive number of ",
                 "logical pixels", call. = FALSE)
        }
        out[[f]] <- as.numeric(d)
    }
    out
}

# Image types glinty can name without being told; the set every
# frontend displays.
IMAGE_MIME <- c(png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg",
                gif = "image/gif", webp = "image/webp", svg = "image/svg+xml")

#' The media type of an image file
#'
#' Read off the extension, which is stated, not guessed. An unknown
#' extension is an error naming the fix rather than a type invented to
#' fill the data URI.
#'
#' @param src character file path
#' @return character media type
#' @keywords internal
image_mime <- function(src) {
    path <- sub("[?#].*$", "", src)
    base <- basename(path)
    ext <- tolower(sub("^.*\\.", "", base))
    if (identical(ext, base) || !ext %in% names(IMAGE_MIME)) {
        stop("cannot read a media type off '", src, "'; render_image() ",
             "embeds ", paste0(".", names(IMAGE_MIME), collapse = " "),
             " files", call. = FALSE)
    }
    unname(IMAGE_MIME[[ext]])
}

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
    if (grepl("^data:", src, ignore.case = TRUE)) {
        declared <- data_uri_mime(src)
        if (is.null(declared)) {
            stop("audio data URI declares no media type; pass mime = ",
                 call. = FALSE)
        }
        return(check_audio_mime(declared))
    }
    ext <- tolower(tools::file_ext(sub("[?#].*$", "", src)))
    if (!ext %in% names(AUDIO_MIME)) {
        stop("cannot name the media type of \"", src,
             "\"; return list(src = , mime = ) instead", call. = FALSE)
    }
    unname(AUDIO_MIME[[ext]])
}

#' The media type a data URI declares, or NULL for anything else
#'
#' @param src character source
#' @return character media type, or NULL when src is not a data URI or
#'   declares no type
#' @keywords internal
data_uri_mime <- function(src) {
    # Case-insensitively, because a URI scheme is: DATA:audio/wav is
    # the same URI as data:audio/wav. Matched literally, the second
    # one was a data URI and the first was a filename with no
    # extension -- so an explicit mime that contradicted it was never
    # compared against anything.
    if (!grepl("^data:", src, ignore.case = TRUE)) {
        return(NULL)
    }
    declared <- tolower(sub("^data:([^;,]*).*$", "\\1", src,
                            ignore.case = TRUE))
    if (!nzchar(declared) || identical(declared, tolower(src))) {
        return(NULL)
    }
    declared
}

#' Refuse a media type that is not one
#'
#' The field names an audio source, so a type outside the audio family
#' is a mistake worth catching where it was made -- a native client
#' would hand it to a player that cannot open it and report something
#' about the file instead.
#'
#' @param mime character lowercase media type
#' @return mime, invisibly refused by stop() when it is not audio
#' @keywords internal
check_audio_mime <- function(mime) {
    if (!grepl("^audio/[!#$%&'*+.^_`|~0-9a-z-]+$", mime)) {
        stop("\"", mime, "\" is not an audio media type", call. = FALSE)
    }
    mime
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
