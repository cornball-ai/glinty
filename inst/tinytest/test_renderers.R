# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
session_end <- glinty:::session_end
with_session <- glinty:::with_session

last_msg <- function(s) jsonlite::fromJSON(s$outgoing[[length(s$outgoing)]])

# --- render_text: kind text, character coercion, collapse ---
s <- new_session("r1")
with_session(s, {
    s$output$txt <- render_text(function() c("a", "b"))
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$type, "output")
expect_equal(m$kind, "text")
expect_equal(m$value, "a b")

# --- bare function still works (browseR compat), kind text ---
with_session(s, {
    s$output$bare <- function() 42
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$kind, "text")
expect_equal(m$value, "42")

# --- render_html: kind html, serializes tags ---
with_session(s, {
    s$output$frag <- render_html(function() "<h3>Hi</h3>")
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$kind, "html")
expect_equal(m$value, "<h3>Hi</h3>")

# --- render_table: structured header/rows on the wire ---
with_session(s, {
    s$output$tbl <- render_table(function() {
        data.frame(name = c("a<b", "c"), n = c(1.5, 2), stringsAsFactors = FALSE)
    })
})
flush_reactions()
raw_json <- s$outgoing[[length(s$outgoing)]]
m <- jsonlite::fromJSON(raw_json, simplifyVector = FALSE)
expect_equal(m$kind, "table")
expect_equal(unlist(m$value$header), c("name", "n"))
expect_equal(unlist(m$value$rows[[1L]]), c("a<b", "1.5"))
expect_equal(unlist(m$value$rows[[2L]]), c("c", "2.0"))
# no markup, no escaping on the wire: strings travel raw
expect_false(grepl("<td>", raw_json, fixed = TRUE))
expect_true(grepl("a<b", rawToChar(charToRaw(raw_json)), fixed = TRUE) ||
    grepl("a\\u003cb", raw_json, fixed = TRUE))

# single-column, single-row frames stay arrays (I() beats auto_unbox)
one <- glinty:::df_to_table(data.frame(x = "only"))
one_json <- as.character(jsonlite::toJSON(
    list(type = "output", id = "t", kind = "table", value = one),
    auto_unbox = TRUE
))
expect_true(grepl('"header":["x"]', one_json, fixed = TRUE))
expect_true(grepl('"rows":[["only"]]', one_json, fixed = TRUE))

# render_table rejects non-data.frames via the error path
with_session(s, {
    s$output$badtbl <- render_table(function() "nope")
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$type, "error")
expect_equal(m$id, "badtbl")

# --- render errors become error messages, flush survives ---
with_session(s, {
    s$output$boom <- render_text(function() stop("kapow"))
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$type, "error")
expect_equal(m$id, "boom")
expect_true(grepl("kapow", m$message))

# --- render_audio: kind audio, value {src, mime, duration?} ---
#
# mime is not optional. A browser sniffs the bytes and never asks,
# which is how the field went missing; a native client hands the
# source to a platform player that does. So the src alone is enough
# to call it -- the type is read out of the extension or out of the
# data URI, both of which state it -- but it always goes on the wire.
with_session(s, {
    s$output$snd <- render_audio(function() "/static/chime.wav")
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$kind, "audio")
expect_equal(m$value$src, "/static/chime.wav")
expect_equal(m$value$mime, "audio/wav")
expect_null(m$value$duration)

# a data URI declares its own type, so that is what is used
with_session(s, {
    s$output$snd2 <- render_audio(function() "data:audio/mpeg;base64,SUQz")
})
flush_reactions()
expect_equal(last_msg(s)$value$mime, "audio/mpeg")

# and an app that knows says so, duration included
with_session(s, {
    s$output$snd3 <- render_audio(function() {
        list(src = "/gen/out.bin", mime = "audio/flac", duration = 12.5)
    })
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$value$mime, "audio/flac")
expect_equal(m$value$duration, 12.5)

# a source whose type cannot be read is an error naming the fix, not
# a media type invented to fill a required field
expect_error(glinty:::audio_mime("/gen/out.bin"), "list(src = , mime = )",
             fixed = TRUE)
expect_error(glinty:::audio_mime("data:;base64,AAAA"), "declares no media type")
# query strings and fragments are not part of the extension
expect_equal(glinty:::audio_mime("/static/a.ogg?v=2"), "audio/ogg")
expect_equal(glinty:::audio_mime("/static/A.MP3"), "audio/mpeg")

# NULL is still "nothing to play", not a value with no source
with_session(s, {
    s$output$snd4 <- render_audio(function() NULL)
})
flush_reactions()
expect_null(last_msg(s)$value)

# --- render_plot: kind image, value {src, width, height} ---
if (capabilities("png")) {
    with_session(s, {
        s$output$plt <- render_plot(function() plot(1:10), width = 200,
            height = 150)
    })
    flush_reactions()
    m <- last_msg(s)
    expect_equal(m$type, "output")
    expect_equal(m$kind, "image")
    expect_true(grepl("^data:image/png;base64,[A-Za-z0-9+/=]+$", m$value$src))
    expect_equal(c(m$value$width, m$value$height), c(200, 150))

    # a plotting error still closes the device and reports
    n_dev <- length(grDevices::dev.list())
    with_session(s, {
        s$output$pltbad <- render_plot(function() stop("no plot"))
    })
    flush_reactions()
    m <- last_msg(s)
    expect_equal(m$type, "error")
    expect_equal(length(grDevices::dev.list()), n_dev)
}

session_end(s)
