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

# --- an audio value is scalars, and says so where the mistake is ---
#
# Every field on this wire is one value. as.character() on a
# two-element vector is a JSON array against a contract that promised
# a string, and the client that meets it can only report that
# something is wrong with the audio -- the app is where it can be
# named.
av <- glinty:::audio_value

expect_error(av(list(src = c("a.wav", "b.wav"))), "one non-empty src")
expect_error(av(list(src = character(0))), "one non-empty src")
expect_error(av(list(src = NA_character_)), "one non-empty src")
expect_error(av(list(src = "")), "one non-empty src")
expect_error(av(list(mime = "audio/wav")), "one non-empty src")
expect_error(av(list(src = 42)), "one non-empty src")

expect_error(av(list(src = "a.wav", mime = c("audio/wav", "audio/mpeg"))),
             "one media type")
expect_error(av(list(src = "a.wav", mime = NA_character_)), "one media type")
expect_error(av(list(src = "a.wav", mime = "text/plain")),
             "not an audio media type")
# a source that is not audio at all is caught on the derived path too
expect_error(av(list(src = "data:image/png;base64,iVBOR")),
             "not an audio media type")

expect_error(av(list(src = "a.wav", duration = c(1, 2))), "one finite")
expect_error(av(list(src = "a.wav", duration = NA_real_)), "one finite")
expect_error(av(list(src = "a.wav", duration = Inf)), "one finite")
expect_error(av(list(src = "a.wav", duration = -1)), "one finite")
expect_error(av(list(src = "a.wav", duration = "12")), "one finite")
# zero is a real length, not a missing one
expect_equal(av(list(src = "a.wav", duration = 0))$duration, 0)

# A data URI states its own type. Two answers to one question is not
# something to pick a winner from: whichever won, the other half of
# the value would be a lie.
expect_error(av(list(src = "data:audio/wav;base64,UklGRg",
                     mime = "audio/mpeg")),
             "declares audio/wav and mime = says audio/mpeg", fixed = TRUE)
# agreeing is fine, and case is not disagreement
expect_equal(av(list(src = "data:audio/wav;base64,UklGRg",
                     mime = "AUDIO/WAV"))$mime, "audio/wav")

# A URI scheme is case-insensitive, so DATA: is the same URI. Matched
# literally it was not a data URI at all -- it was a filename with no
# extension, and the type it declares had nothing to be compared
# against.
expect_equal(glinty:::data_uri_mime("DATA:audio/wav;base64,UklGRg"),
             "audio/wav")
expect_equal(av(list(src = "Data:AUDIO/Wav;base64,UklGRg"))$mime,
             "audio/wav")
expect_error(av(list(src = "DATA:audio/wav;base64,UklGRg",
                     mime = "audio/mpeg")),
             "declares audio/wav and mime = says audio/mpeg", fixed = TRUE)
expect_error(av(list(src = "DATA:;base64,UklGRg")),
             "declares no media type")
# and a path carries no declaration to contradict
expect_equal(av(list(src = "/gen/out.bin", mime = "audio/flac"))$mime,
             "audio/flac")

# The refusal reaches the slot that asked, as an error frame scoped to
# it. A malformed value is an app bug, and an app bug in one output is
# not a reason to take the session down.
with_session(s, {
    s$output$bad_snd <- render_audio(function() {
        list(src = "data:audio/wav;base64,UklGRg", duration = -3)
    })
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$type, "error")
expect_equal(m$id, "bad_snd")
expect_true(grepl("finite, non-negative", m$message))

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

# --- render_image: kind image, value {src, width?, height?} ---
#
# A source the client can already fetch passes through; a file that
# exists on the server is embedded as a data URI, because a server
# path means nothing across the wire.
s <- new_session("rimg")
with_session(s, {
    s$output$logo <- render_image(function() "/static/logo.png")
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$kind, "image")
expect_equal(m$value$src, "/static/logo.png")
expect_null(m$value$width)

with_session(s, {
    s$output$dataimg <- render_image(function() "data:image/png;base64,AAAA")
})
flush_reactions()
expect_equal(last_msg(s)$value$src, "data:image/png;base64,AAAA")

# A real file on disk becomes a data URI carrying its stated type.
imgfile <- tempfile(fileext = ".png")
grDevices::png(imgfile, width = 50, height = 50)
graphics::par(mar = c(0, 0, 0, 0))
plot.new()
grDevices::dev.off()
with_session(s, {
    s$output$still <- render_image(function() {
        list(src = imgfile, width = 320, height = 180)
    })
})
flush_reactions()
m <- last_msg(s)
expect_true(startsWith(m$value$src, "data:image/png;base64,"))
expect_equal(m$value$width, 320)
expect_equal(m$value$height, 180)
unlink(imgfile)

# A file whose type cannot be read is an error naming the fix, not a
# media type invented to fill the URI.
binfile <- tempfile(fileext = ".bin")
writeLines("x", binfile)
expect_error(glinty:::image_value(list(src = binfile)),
             "cannot read a media type")
unlink(binfile)
expect_error(glinty:::image_mime("/x/noext"), "cannot read a media type")
# query strings and fragments are not part of the extension
expect_equal(glinty:::image_mime("/x/a.webp?v=2"), "image/webp")

# Scalars only: shapes that would lie on the wire are refused here.
expect_error(glinty:::image_value(list(src = c("a", "b"))), "one non-empty")
expect_error(glinty:::image_value(list(src = "")), "one non-empty")
expect_error(glinty:::image_value(list(src = "/static/a.png", width = -1)),
             "positive number")
expect_error(glinty:::image_value(list(src = "/static/a.png",
                                       height = c(1, 2))),
             "positive number")
session_end(s)
