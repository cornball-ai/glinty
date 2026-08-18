# HTML-UI e2e in-process: 03-reactivity's graph in a plain page.
# One shared reactive feeds three outputs; either input reroutes all
# three; the head table is always 6 rows.
source("../../tools/drive.R")

d <- drive_boot("app.R", "html")
drive_measure(d, "plot", 700, 300)

n <- function(id) length(drive_msgs(d, type = "output", id = id))
last <- function(id) {
    m <- drive_msgs(d, type = "output", id = id)
    m[[length(m)]]$value
}

# --- boot: all three render; the plot once default, once measured
stopifnot(n("summary") == 1L, n("table") == 1L)
stopifnot(grepl("^data:image/png", last("plot")$src))
stopifnot(grepl("Median", last("summary")))
stopifnot(length(last("table")$rows) == 6L)
p_n <- n("plot")
cat("boot: summary, 6-row head, plot raster\n")

# --- dist change reroutes everything
p0 <- last("plot")$src
drive_input(d, "dist", "exp")
stopifnot(n("plot") == p_n + 1L, n("summary") == 2L, n("table") == 2L)
stopifnot(!identical(p0, last("plot")$src))
cat("dist -> exp: all three re-emitted\n")

# --- n change likewise; head stays 6 rows regardless of n
drive_input(d, "n", 25)
stopifnot(n("plot") == p_n + 2L, n("summary") == 3L)
stopifnot(length(last("table")$rows) == 6L)
cat("n -> 25: re-emitted, head still 6\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("HTML-UI OK\n")
