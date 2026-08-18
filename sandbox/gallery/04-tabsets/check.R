# Tabsets e2e in-process: one reactive feeds three outputs across
# tabs; the tab input itself is a value; every control reroutes the
# data everywhere at once.
source("../../tools/drive.R")

d <- drive_boot("app.R", "tabsets")
drive_measure(d, "plot", 700, 300)

n <- function(id) length(drive_msgs(d, type = "output", id = id))
last <- function(id) {
    m <- drive_msgs(d, type = "output", id = id)
    m[[length(m)]]$value
}

# --- boot: all three outputs render (glinty renders hidden tabs
#     too), the plot once at its default size and once measured
stopifnot(n("summary") == 1L, n("table") == 1L)
stopifnot(grepl("^data:image/png", last("plot")$src))
stopifnot(grepl("Median", last("summary")))
stopifnot(length(last("table")$rows) == 500L)
stopifnot(identical(unlist(last("table")$align), "num"))
p_n <- n("plot")
cat("boot: plot raster, summary, 500-row numeric table\n")

# --- distribution change reroutes everything through the reactive
p0 <- last("plot")$src
drive_input(d, "dist", "exp")
stopifnot(n("plot") == p_n + 1L, n("summary") == 2L, n("table") == 2L)
stopifnot(!identical(p0, last("plot")$src))
cat("dist -> exp: all three re-emitted\n")

# --- n change likewise, and the table length tracks it
drive_input(d, "n", 25)
stopifnot(n("plot") == p_n + 2L, length(last("table")$rows) == 25L)
cat("n -> 25: re-emitted, 25 rows\n")

# --- the tabset is an input: switching tabs is a value the server
#     can see, and triggers no re-render by itself
drive_input(d, "view", "Summary")
stopifnot(n("plot") == p_n + 2L, n("summary") == 3L, n("table") == 3L)
cat("tab switch: an input, not a re-render\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("TABSETS OK\n")
