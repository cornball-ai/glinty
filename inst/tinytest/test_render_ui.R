# render_ui / ui_output: dynamic tag trees on the wire, both frontends

.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

# --- ui_output shape ---
uo <- ui_output("panel")
expect_equal(uo$component, "ui_output")

# --- renderer: structured tag tree with bind; NULL travels as null ---
s <- glinty:::new_session("ru1")
show <- reactive_val(FALSE)
glinty:::with_session(s, {
    s$output$panel <- render_ui(function() {
        if (show()) {
            column(
                heading("Details", level = 4L),
                text_input("extra", "Extra:", value = "seed"),
                button("go2", "Go")
            )
        } else {
            NULL
        }
    })
})
flush_reactions()
raw1 <- s$outgoing[[length(s$outgoing)]]
m1 <- jsonlite::fromJSON(raw1, simplifyVector = FALSE)
expect_equal(m1$kind, "ui")
expect_null(m1$value)
expect_true(grepl('"value":null', raw1, fixed = TRUE))

show(TRUE)
flush_reactions()
raw2 <- s$outgoing[[length(s$outgoing)]]
m2 <- jsonlite::fromJSON(raw2, simplifyVector = FALSE)
expect_equal(m2$value$component, "column")
kids <- m2$value$children
expect_equal(kids[[1L]]$component, "heading")
expect_equal(kids[[1L]]$value, "Details")
# the nested input survives with its fields intact
inner_input <- kids[[2L]]
expect_equal(inner_input$component, "text_input")
expect_equal(inner_input$emit, "live")
expect_equal(inner_input$id, "extra")
expect_equal(kids[[3L]]$component, "button")

# a non-component return errors through the output error path
glinty:::with_session(s, {
    s$output$bad <- render_ui(function() "raw strings not allowed")
})
flush_reactions()
mb <- jsonlite::fromJSON(s$outgoing[[length(s$outgoing)]])
expect_equal(mb$type, "error")
expect_true(grepl("component", mb$message))
glinty:::session_end(s)

# The native-backend parity block lived here. flitR is archived
# and its lowering is gone; the second frontend is now the Flutter
# renderer in dart/glinty_flutter, tested there.

# --- outputs inside dynamic UI replay their last state on show ---
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

s3 <- glinty:::new_session("ru3")
visible <- reactive_val(FALSE)
counter <- reactive_val(41L)
glinty:::with_session(s3, {
    s3$output$live_count <- render_text(function() counter())
    s3$output$wrap <- render_ui(function() {
        if (visible()) column(heading("Panel", level = 4L),
            text_output("live_count")) else NULL
    })
})
flush_reactions()
# live_count updated while its element is absent client-side
counter(42L)
flush_reactions()
s3$outgoing <- list()

visible(TRUE)
flush_reactions()
msgs <- lapply(s3$outgoing, function(m) jsonlite::fromJSON(m,
    simplifyVector = FALSE))
kinds_seen <- vapply(msgs, function(m) {
    if (is.null(m$kind)) "" else m$kind
}, character(1L))
ui_at <- which(kinds_seen == "ui")
expect_equal(length(ui_at), 1L)
# the ui update is followed by a replay of live_count's last state
later <- msgs[seq_along(msgs) > ui_at]
replayed <- Filter(function(m) identical(m$id, "live_count"), later)
expect_equal(length(replayed), 1L)
expect_equal(replayed[[1L]]$value, "42")
glinty:::session_end(s3)

