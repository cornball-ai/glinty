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
