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

# --- render_audio: kind audio, value {src} ---
with_session(s, {
    s$output$snd <- render_audio(function() "/static/chime.wav")
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$kind, "audio")
expect_equal(m$value$src, "/static/chime.wav")

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
