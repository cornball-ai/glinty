# Sliders e2e in-process: five sliders, one table. The table is the
# whole app, so every check is "does the right row change".
source("../../tools/drive.R")

d <- drive_boot("app.R", "sliders")

n <- function() length(drive_msgs(d, type = "output", id = "values"))
val <- function(row) {
    m <- drive_msgs(d, type = "output", id = "values")
    tbl <- m[[length(m)]]$value
    unlist(tbl$rows[[row]])[[2L]]
}

# --- boot: the seeded table shows every slider's initial position,
#     the range as its pair
stopifnot(n() == 1L)
stopifnot(val(1L) == "500")
stopifnot(val(2L) == "0.5")
stopifnot(val(3L) == "200 500")
stopifnot(val(4L) == "0")
stopifnot(val(5L) == "1")
cat("boot: all five rows seeded\n")

# --- single sliders update their row
drive_input(d, "integer", 750)
stopifnot(n() == 2L, val(1L) == "750")
drive_input(d, "decimal", 0.8)
stopifnot(val(2L) == "0.8")
cat("single sliders: rows track\n")

# --- the range is one input carrying a pair (post-normalize_value
#     form: a numeric vector, same shape the seed gives)
drive_input(d, "range", c(300, 700))
stopifnot(val(3L) == "300 700")
cat("range: pair in, pair shown\n")

# --- the wire form (a JSON array) normalizes to that same vector
stopifnot(identical(glinty:::normalize_value(list(150L, 850L)),
    c(150L, 850L)))
cat("wire pair normalizes to a vector\n")

drive_input(d, "format", 7500)
drive_input(d, "animation", 1001)
stopifnot(val(4L) == "7500", val(5L) == "1001")
stopifnot(n() == 6L)

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("SLIDERS OK\n")
