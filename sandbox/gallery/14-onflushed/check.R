# onFlushed e2e in-process: the boot flush is cheap and carries
# placeholders; the expensive work happens only after the loop's
# post-drain on_flushed fire. Wall-clock is part of the contract
# here, so the check times both phases.
source("../../tools/drive.R")

t0 <- Sys.time()
d <- drive_boot("app.R")
drive_measure(d, "slow_plot", 700, 400)
boot_s <- as.numeric(Sys.time()) - as.numeric(t0)

last <- function(id) {
    m <- drive_msgs(d, type = "output", id = id)
    m[[length(m)]]$value
}
n <- function(id) length(drive_msgs(d, type = "output", id = id))

# --- phase 1: placeholders, and the boot did not pay for the work
stopifnot(boot_s < 3)
stopifnot(grepl("right away", last("fast")))
stopifnot(grepl("Please wait for 5 seconds", last("slow")))
p1 <- last("slow_plot")$src
stopifnot(grepl("^data:image/png", p1))
cat(sprintf("boot in %.2fs: placeholders only\n", boot_s))

# --- phase 2: the loop spins, on_flushed flips, the work happens
t1 <- Sys.time()
drive_settle(d)
settle_s <- as.numeric(Sys.time()) - as.numeric(t1)
stopifnot(settle_s >= 5)
stopifnot(n("slow") == 2L)
stopifnot(grepl("This happens later", last("slow")))
stopifnot(n("fast") == 1L) # the fast output never re-rendered
p2 <- last("slow_plot")$src
stopifnot(!identical(p1, p2)) # cars placeholder -> rnorm plot
cat(sprintf("settle in %.2fs: deferred work done after first paint\n",
            settle_s))

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("onFlushed OK\n")
