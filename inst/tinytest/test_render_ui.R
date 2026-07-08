# render_ui / ui_output: dynamic tag trees on the wire, both frontends

.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

# --- ui_output shape ---
uo <- ui_output("panel")
expect_equal(uo$attrs$class, "g-ui-output")

# --- renderer: structured tag tree with bind; NULL travels as null ---
s <- glinty:::new_session("ru1")
show <- reactive_val(FALSE)
glinty:::with_session(s, {
    s$output$panel <- render_ui(function() {
        if (show()) {
            div(
                h4("Details"),
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
expect_equal(m1$property, "ui")
expect_null(m1$value)
expect_true(grepl('"value":null', raw1, fixed = TRUE))

show(TRUE)
flush_reactions()
raw2 <- s$outgoing[[length(s$outgoing)]]
m2 <- jsonlite::fromJSON(raw2, simplifyVector = FALSE)
expect_equal(m2$value$tag, "div")
kids <- m2$value$children
expect_equal(kids[[1L]]$tag, "h4")
expect_equal(kids[[1L]]$text, "Details")
# the nested input keeps its event binding
inner_input <- kids[[2L]]$children[[2L]]
expect_equal(inner_input$tag, "input")
expect_equal(inner_input$bind$event, "input")
expect_equal(inner_input$bind$target, "extra")
expect_equal(kids[[3L]]$bind$event, "click")

# non-tag return errors through the output error path
glinty:::with_session(s, {
    s$output$bad <- render_ui(function() "raw strings not allowed")
})
flush_reactions()
mb <- jsonlite::fromJSON(s$outgoing[[length(s$outgoing)]])
expect_equal(mb$type, "error")
expect_true(grepl("glinty_tag", mb$message))
glinty:::session_end(s)

# --- native: stored tree translates; dynamic widgets wire up ---
if (requireNamespace("flitR", quietly = TRUE) &&
    "render_dirty" %in% getNamespaceExports("flitR")) {
    s2 <- glinty:::new_session("ru2")
    values <- new.env(parent = emptyenv())

    flatten <- function(x) {
        if (is.list(x) && !is.null(x$op)) {
            return(list(x))
        }
        if (is.list(x)) {
            return(do.call(c, c(lapply(x, flatten), list(list()))))
        }
        list()
    }

    ui <- page(ui_output("panel"))

    # empty until a value arrives
    ops0 <- flatten(glinty:::build_native_ops(ui, s2, values))
    expect_equal(length(Filter(function(o) identical(o$op, "hit"), ops0)),
        0L)

    # simulate the wire: renderer JSON -> native_apply -> values
    native <- new.env(parent = emptyenv())
    native$dirty <- FALSE
    glinty:::native_apply(raw2, values, native)
    expect_true(native$dirty)

    ops1 <- flatten(glinty:::build_native_ops(ui, s2, values))
    hits <- Filter(function(o) identical(o$op, "hit"), ops1)
    ids <- vapply(hits, function(h) h$id, character(1L))
    expect_true(all(c("extra", "go2") %in% ids))

    # dynamic button routes through glinty's click handler
    go_hit <- hits[[which(ids == "go2")]]
    go_hit$on_click()
    flush_reactions()
    expect_equal(isolate(s2$input$go2()), 1L)

    # dynamic text input carries its seeded value and routes changes
    extra_hit <- hits[[which(ids == "extra")]]
    expect_equal(extra_hit$input$value, "seed")
    extra_hit$input$on_change("typed")
    flush_reactions()
    expect_equal(isolate(s2$input$extra()), "typed")

    # null value clears the panel
    glinty:::native_apply(raw1, values, native)
    ops2 <- flatten(glinty:::build_native_ops(ui, s2, values))
    expect_equal(length(Filter(function(o) identical(o$op, "hit"), ops2)),
        0L)

    glinty:::session_end(s2)
}

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
        if (visible()) div(h4("Panel"), text_output("live_count")) else NULL
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
props <- vapply(msgs, function(m) {
    if (is.null(m$property)) "" else m$property
}, character(1L))
ui_at <- which(props == "ui")
expect_equal(length(ui_at), 1L)
# the ui update is followed by a replay of live_count's last state
later <- msgs[seq_along(msgs) > ui_at]
replayed <- Filter(function(m) identical(m$id, "live_count"), later)
expect_equal(length(replayed), 1L)
expect_equal(replayed[[1L]]$value, "42")
glinty:::session_end(s3)
