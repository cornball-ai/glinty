# reset state
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL
.g$timers <- list()

schedule_timer <- glinty:::schedule_timer
cancel_timer <- glinty:::cancel_timer
next_timer_deadline <- glinty:::next_timer_deadline
run_due_timers <- glinty:::run_due_timers

# --- deadline math with an injected clock ---
expect_null(next_timer_deadline(now = 100))

fired <- character(0)
schedule_timer(5, function() fired <<- c(fired, "b"), now = 100)
schedule_timer(1, function() fired <<- c(fired, "a"), now = 100)
expect_equal(next_timer_deadline(now = 100), 1)
expect_equal(next_timer_deadline(now = 100.5), 0.5)
# past-due deadline clamps to 0
expect_equal(next_timer_deadline(now = 102), 0)

# --- nothing fires early ---
expect_equal(run_due_timers(now = 100.9), 0L)
expect_equal(fired, character(0))

# --- due timers fire in deadline order, one sweep can fire several ---
expect_equal(run_due_timers(now = 106), 2L)
expect_equal(fired, c("a", "b"))
expect_null(next_timer_deadline(now = 106))

# --- one-shot: fired timers are gone ---
expect_equal(run_due_timers(now = 200), 0L)

# --- cancel removes a pending timer ---
id <- schedule_timer(1, function() fired <<- c(fired, "never"), now = 100)
cancel_timer(id)
expect_equal(run_due_timers(now = 300), 0L)
expect_equal(fired, c("a", "b"))

# --- a failing callback warns but does not stop the sweep ---
schedule_timer(1, function() stop("boom"), now = 100)
schedule_timer(2, function() fired <<- c(fired, "after-boom"), now = 100)
expect_warning(n <- run_due_timers(now = 110))
expect_equal(n, 2L)
expect_equal(fired, c("a", "b", "after-boom"))

# --- invalidate_later re-arms through observer re-runs ---
.g$timers <- list()
runs <- 0L
observe(function() {
    invalidate_later(1000)
    runs <<- runs + 1L
})
expect_equal(runs, 1L)
expect_equal(length(.g$timers), 1L)

run_due_timers(now = timer_now <- as.numeric(Sys.time()) + 10)
flush_reactions()
expect_equal(runs, 2L)
# the re-run re-armed the timer
expect_equal(length(.g$timers), 1L)

# --- invalidate_later outside a reactive context errors ---
expect_error(invalidate_later(100))

# --- timers of an ended session are inert ---
.g$timers <- list()
s <- glinty:::new_session("timer-s")
s_runs <- 0L
glinty:::with_session(s, {
    observe(function() {
        invalidate_later(1000)
        s_runs <<- s_runs + 1L
    })
})
expect_equal(s_runs, 1L)
glinty:::session_end(s)
run_due_timers(now = as.numeric(Sys.time()) + 10)
flush_reactions()
expect_equal(s_runs, 1L)
.g$timers <- list()
