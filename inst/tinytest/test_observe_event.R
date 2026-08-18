# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

# --- ignore_init (default): no fire at creation, fires on change ---
ev <- reactive_val(NULL)
hits <- 0L
observe_event(ev, function() hits <<- hits + 1L)
flush_reactions()
expect_equal(hits, 0L)

ev("go")
flush_reactions()
expect_equal(hits, 1L)

# --- ignore_null (default): non-truthy event values do not fire ---
ev(NULL)
flush_reactions()
expect_equal(hits, 1L)
ev("")
flush_reactions()
expect_equal(hits, 1L)
ev("again")
flush_reactions()
expect_equal(hits, 2L)

# --- ignore_init = FALSE fires at creation when truthy ---
ev2 <- reactive_val("ready")
hits2 <- 0L
observe_event(ev2, function() hits2 <<- hits2 + 1L, ignore_init = FALSE)
expect_equal(hits2, 1L)

# --- one-arg handlers receive the event value ---
ev3 <- reactive_val(NULL)
seen <- NULL
observe_event(ev3, function(v) seen <<- v)
ev3(42)
flush_reactions()
expect_equal(seen, 42)

# --- handler reads are isolated: other reactives create no deps ---
ev4 <- reactive_val(NULL)
other <- reactive_val(1)
hits4 <- 0L
observe_event(ev4, function() {
    other()
    hits4 <<- hits4 + 1L
})
ev4("x")
flush_reactions()
expect_equal(hits4, 1L)
other(2)
flush_reactions()
expect_equal(hits4, 1L)

# --- once: destroys after first handler run ---
ev5 <- reactive_val(NULL)
hits5 <- 0L
observe_event(ev5, function() hits5 <<- hits5 + 1L, once = TRUE)
ev5(1)
flush_reactions()
ev5(2)
flush_reactions()
expect_equal(hits5, 1L)

# --- once + ignore_init = FALSE fires exactly once, at creation ---
ev6 <- reactive_val("now")
hits6 <- 0L
observe_event(ev6, function() hits6 <<- hits6 + 1L,
    ignore_init = FALSE, once = TRUE)
ev6("later")
flush_reactions()
expect_equal(hits6, 1L)

# --- event_fn must be a function ---
expect_error(observe_event(42, function() NULL))

# --- v3.1: a button's value rides on its event ---
#
# One handler serves a list of rows. Without it every row needs its
# own id and its own observer, which is impossible when the rows are
# built per render -- exactly what the history lists in earshot and
# cornfab do.
new_session <- glinty:::new_session
handle_event <- glinty:::handle_event
dispatch <- glinty:::dispatch_client_message

s <- new_session("ev1")

# a valueless button still counts, which is what every existing
# action button depends on
handle_event(s, "go")
expect_equal(isolate(s$input$go()), 1L)
handle_event(s, "go")
expect_equal(isolate(s$input$go()), 2L)

# a valued button holds the value instead
handle_event(s, "history_view", "entry_7")
expect_equal(isolate(s$input$history_view()), "entry_7")

# and pressing the same row twice still invalidates: this is an
# event, not an input that ignores repeats
fires <- 0L
observe_event(s$input$history_view, function() fires <<- fires + 1L)
flush_reactions()
before <- fires
handle_event(s, "history_view", "entry_7")
flush_reactions()
expect_equal(fires, before + 1L)

# --- the wire form, through the dispatcher ---
s2 <- new_session("ev2")
j <- function(...) as.character(jsonlite::toJSON(list(...), auto_unbox = TRUE))
dispatch(s2, j(type = "event", id = "row_click", value = "abc"))
expect_equal(isolate(s2$input$row_click()), "abc")

# a value that is not a single string is no value, not something
# written into session state unchecked
dispatch(s2, j(type = "event", id = "counted", value = list(1, 2)))
expect_equal(isolate(s2$input$counted()), 1L)
dispatch(s2, j(type = "event", id = "counted2"))
expect_equal(isolate(s2$input$counted2()), 1L)

# reserved ids stay refused on the event path too -- an event was the
# one client-to-server message that never checked
dispatch(s2, j(type = "event", id = "..modal_close"))
expect_false(exists("..modal_close", envir = s2$input_env))

# --- frames coalesce; handlers still observe wire order ---
#
# The composer contract: clear_on emits input(draft), event(send),
# input("") back to back, and one TCP read routinely delivers all
# three before the loop's next flush. The event's handler must read
# the draft as of the event, not as of the end of the batch -- which
# means dispatch itself flushes, instead of letting the trailing ""
# overwrite the store first. This is exactly the batch a browser
# sends on Enter; no flush_reactions() between dispatches on purpose.
s3 <- new_session("ev3")
glinty:::handle_input(s3, "draft", "")
seen <- NULL
observe_event(s3$input$send, function() seen <<- s3$input$draft())
flush_reactions()
dispatch(s3, j(type = "input", id = "draft", value = "the full draft"))
dispatch(s3, j(type = "event", id = "send"))
dispatch(s3, j(type = "input", id = "draft", value = ""))
expect_equal(seen, "the full draft")
expect_equal(isolate(s3$input$draft()), "")
