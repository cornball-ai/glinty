# mpg e2e in-process: one reactive formula string feeds a heading
# caption and a boxplot; the checkbox re-renders the plot only.
source("../../tools/drive.R")

d <- drive_boot("app.R", "mpg")
drive_measure(d, "mpg_plot", 700, 400)

n <- function(id) length(drive_msgs(d, type = "output", id = id))
last <- function(id) {
    m <- drive_msgs(d, type = "output", id = id)
    m[[length(m)]]$value
}

# --- boot: caption is the formula, plot rasterizes (default + measured)
stopifnot(last("caption") == "mpg ~ cyl")
stopifnot(grepl("^data:image/png", last("mpg_plot")$src))
p_n <- n("mpg_plot")
c_n <- n("caption")
cat("boot: caption 'mpg ~ cyl', plot raster\n")

# --- the checkbox touches only the plot. Checked on cyl because it
#     is the one grouping with outliers to hide (am and gear have
#     none, and hiding nothing draws identical bytes).
p0 <- last("mpg_plot")$src
drive_input(d, "outliers", FALSE)
stopifnot(n("caption") == c_n, n("mpg_plot") == p_n + 1L)
stopifnot(!identical(p0, last("mpg_plot")$src))
cat("outliers off: plot only, pixels moved\n")

# --- variable change flows through the shared reactive to both
p1 <- last("mpg_plot")$src
drive_input(d, "variable", "am")
stopifnot(last("caption") == "mpg ~ am")
stopifnot(n("caption") == c_n + 1L, n("mpg_plot") == p_n + 2L)
stopifnot(!identical(p1, last("mpg_plot")$src))
cat("variable -> am: caption and plot re-emitted\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("MPG OK\n")
