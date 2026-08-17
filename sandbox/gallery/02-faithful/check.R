# Faithful e2e in-process: every control changes the raster.
source("../../tools/drive.R")

d <- drive_boot("app.R", "faithful2")
drive_measure(d, "main_plot", 900, 300)

raster <- function() {
    m <- drive_msgs(d, type = "output", id = "main_plot")
    m[[length(m)]]$value$src
}
n_out <- function() length(drive_msgs(d, type = "output", id = "main_plot"))

r0 <- raster()
stopifnot(grepl("^data:image/png;base64,", r0))

drive_input(d, "n_breaks", "50")
r1 <- raster(); stopifnot(!identical(r0, r1))
cat("bins 20 -> 50: raster changed\n")

drive_input(d, "individual_obs", TRUE)
r2 <- raster(); stopifnot(!identical(r1, r2))
cat("rug on: raster changed\n")

drive_input(d, "density", TRUE)
r3 <- raster(); stopifnot(!identical(r2, r3))
cat("density on: raster changed\n")

drive_input(d, "bw_adjust", 0.4)
r4 <- raster(); stopifnot(!identical(r3, r4))
cat("bandwidth 1 -> 0.4: raster changed\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("frames:", n_out(), "outputs, 0 errors\nFAITHFUL2 OK\n")
