# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
session_end <- glinty:::session_end
with_session <- glinty:::with_session
drain_session <- glinty:::drain_session
handle_input <- glinty:::handle_input
handle_event <- glinty:::handle_event

# --- two sessions with the same output id stay isolated ---
s1 <- new_session("s1")
s2 <- new_session("s2")

with_session(s1, {
    s1$output$greeting <- function() paste("hello", s1$input$name())
})
with_session(s2, {
    s2$output$greeting <- function() paste("hola", s2$input$name())
})
flush_reactions()
s1$outgoing <- list()
s2$outgoing <- list()

handle_input(s1, "name", "troy")
flush_reactions()

# only s1 got a message, and it is the right one
expect_equal(length(s1$outgoing), 1L)
expect_equal(length(s2$outgoing), 0L)
expect_true(grepl("hello troy", s1$outgoing[[1L]]))

handle_input(s2, "name", "jorge")
flush_reactions()
expect_equal(length(s2$outgoing), 1L)
expect_true(grepl("hola jorge", s2$outgoing[[1L]]))
expect_equal(length(s1$outgoing), 1L)

# --- observers are tagged with their session ---
expect_true(length(s1$observers) >= 1L)
expect_true(length(s2$observers) >= 1L)

# --- session_end destroys observers: no messages after end ---
session_end(s1)
expect_true(s1$ended)
handle_input(s1, "name", "ghost")
flush_reactions()
expect_equal(length(s1$outgoing), 0L)

# s2 still lives
handle_input(s2, "name", "still here")
flush_reactions()
expect_equal(length(s2$outgoing), 2L)

# --- on_ended fires exactly once (session_end is idempotent) ---
fired <- 0L
s3 <- new_session("s3")
s3$on_ended(function() fired <<- fired + 1L)
session_end(s3)
session_end(s3)
expect_equal(fired, 1L)

# --- session registry add/remove ---
expect_false(exists("s1", envir = .g$sessions))
expect_true(exists("s2", envir = .g$sessions))
session_end(s2)
expect_false(exists("s2", envir = .g$sessions))

# --- click counter semantics ---
s4 <- new_session("s4")
clicks <- integer(0)
with_session(s4, {
    obs <- observe(function() {
        n <- s4$input$go()
        if (!is.null(n)) clicks <<- c(clicks, n)
    })
})
flush_reactions()
handle_event(s4, "go")
flush_reactions()
handle_event(s4, "go")
flush_reactions()
expect_equal(clicks, c(1L, 2L))
session_end(s4)

# --- drain_session empties the queue and forwards via send_fn ---
sent <- character(0)
s5 <- new_session("s5", send_fn = function(m) sent <<- c(sent, m))
s5$send("msg-a")
s5$send("msg-b")
msgs <- drain_session(s5)
expect_equal(length(s5$outgoing), 0L)
expect_equal(sent, c("msg-a", "msg-b"))
session_end(s5)

# --- [[ access on input proxy ---
s6 <- new_session("s6")
expect_null(s6$input[["dyn"]]())
handle_input(s6, "dyn", 42)
expect_equal(isolate(s6$input[["dyn"]]()), 42)
session_end(s6)

# --- on_flushed: once, after the drain, session-scoped ---
#
# Registration is inert through any number of flushes; the event
# loop's post-drain fire_on_flushed() is what runs it, exactly once.
# That "after the drain" placement is the whole point: the callback
# runs only when the flush's messages have left for the client.
s7 <- new_session("s7")
hits <- 0L
s7$on_flushed(function() hits <<- hits + 1L)
expect_equal(hits, 0L)
flush_reactions()
expect_equal(hits, 0L)
expect_equal(glinty:::fire_on_flushed(), 1L)
expect_equal(hits, 1L)
# once means once
expect_equal(glinty:::fire_on_flushed(), 0L)
expect_equal(hits, 1L)

# a callback registering another defers it to the NEXT fire -- the
# re-register idiom for every-flush behavior terminates each round
s7$on_flushed(function() {
    hits <<- hits + 1L
    s7$on_flushed(function() hits <<- hits + 100L)
})
glinty:::fire_on_flushed()
expect_equal(hits, 2L)
glinty:::fire_on_flushed()
expect_equal(hits, 102L)

# one failing callback warns and does not eat its neighbors
s7$on_flushed(function() stop("boom"))
s7$on_flushed(function() hits <<- hits + 1L)
expect_warning(glinty:::fire_on_flushed(), "on_flushed callback failed")
expect_equal(hits, 103L)
session_end(s7)

# an ended session's callbacks never fire
s8 <- new_session("s8")
s8$on_flushed(function() hits <<- hits + 1000L)
session_end(s8)
expect_equal(glinty:::fire_on_flushed(), 0L)
expect_equal(hits, 103L)

# the deferred-render pattern end to end: placeholder first, the
# expensive value only after the flush that carried the placeholder
s9 <- new_session("s9")
with_session(s9, {
    starting <- glinty::reactive_val(TRUE)
    s9$on_flushed(function() starting(FALSE))
    s9$output$slow <- glinty::render_text(function() {
        if (starting()) "placeholder" else "expensive"
    })
})
flush_reactions()
vals <- function() vapply(Filter(function(m) grepl('"id":"slow"', m),
                                 s9$outgoing),
                          function(m) jsonlite::fromJSON(m)$value,
                          character(1L))
expect_equal(vals(), "placeholder")
glinty:::fire_on_flushed()
flush_reactions()
expect_equal(vals(), c("placeholder", "expensive"))
session_end(s9)
