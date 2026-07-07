# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
session_end <- glinty:::session_end
with_session <- glinty:::with_session

last_msg <- function(s) jsonlite::fromJSON(s$outgoing[[length(s$outgoing)]])

# --- render_text: textContent, character coercion, collapse ---
s <- new_session("r1")
with_session(s, {
    s$output$txt <- render_text(function() c("a", "b"))
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$type, "update")
expect_equal(m$property, "textContent")
expect_equal(m$value, "a b")

# --- bare function still works (browseR compat), textContent ---
with_session(s, {
    s$output$bare <- function() 42
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$property, "textContent")
expect_equal(m$value, "42")

# --- render_html: innerHTML, serializes tags ---
with_session(s, {
    s$output$frag <- render_html(function() div(h3("Hi")))
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$property, "innerHTML")
expect_equal(m$value, "<div><h3>Hi</h3></div>")

# --- render_table: escaped cells, header row ---
with_session(s, {
    s$output$tbl <- render_table(function() {
        data.frame(name = c("a<b", "c"), n = c(1.5, 2), stringsAsFactors = FALSE)
    })
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$property, "innerHTML")
expect_true(grepl("<th>name</th><th>n</th>", m$value))
expect_true(grepl("<td>a&lt;b</td>", m$value))
expect_true(grepl("<td>1.5</td>", m$value))

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

# --- render_audio: src passthrough ---
with_session(s, {
    s$output$snd <- render_audio(function() "/static/chime.wav")
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$property, "src")
expect_equal(m$value, "/static/chime.wav")

# --- render_plot: data URI, gated on png support ---
if (capabilities("png")) {
    with_session(s, {
        s$output$plt <- render_plot(function() plot(1:10), width = 200,
            height = 150)
    })
    flush_reactions()
    m <- last_msg(s)
    expect_equal(m$type, "update")
    expect_equal(m$property, "src")
    expect_true(grepl("^data:image/png;base64,[A-Za-z0-9+/=]+$", m$value))

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
