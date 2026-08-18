# Timer e2e in-process: the render re-arms itself. Timers are
# driven by hand (run_due_timers at a chosen now), so the check is
# deterministic -- no sleeps.
source("../../tools/drive.R")

d <- drive_boot("app.R", "timer")

n <- function() length(drive_msgs(d, type = "output", id = "current_time"))
last <- function() {
    m <- drive_msgs(d, type = "output", id = "current_time")
    m[[length(m)]]$value
}

# --- boot: one render, carrying a time
stopifnot(n() == 1L)
stopifnot(grepl("The current time is 20", last()))
cat("boot: clock rendered\n")

# --- a due sweep re-runs the render, which re-arms for the next
run_due_timers <- glinty:::run_due_timers
for (i in 1:3) {
    fired <- run_due_timers(now = as.numeric(Sys.time()) + i * 10)
    glinty::flush_reactions()
    stopifnot(fired == 1L, n() == 1L + i)
}
cat("three sweeps: three re-renders, timer re-armed each time\n")

# --- nothing due, nothing fires
stopifnot(run_due_timers(now = as.numeric(Sys.time()) - 1000) == 0L)
stopifnot(n() == 4L)
cat("not due: quiet\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("TIMER OK\n")
