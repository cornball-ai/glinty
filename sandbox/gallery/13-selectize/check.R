# Selectize e2e in-process: the search select is a select to the
# server -- same seed, same value domain, same input frames. That is
# the whole design, and this file is what pins it.
source("../../tools/drive.R")

d <- drive_boot("app.R")

last <- function(id) {
    m <- drive_msgs(d, type = "output", id = id)
    m[[length(m)]]$value
}
n <- function(id) length(drive_msgs(d, type = "output", id = id))

# --- boot: singles seed to the first choice, multis to empty
stopifnot(identical(glinty::isolate(d$input$e0()), "Alabama"))
stopifnot(identical(glinty::isolate(d$input$e1()), "Alabama"))
stopifnot(identical(glinty::isolate(d$input$e2()), character(0)))
stopifnot(n("ex_out") == 1L)
stopifnot(grepl("Alabama", last("ex_out")))
cat("boot: search select seeds exactly like a plain select\n")

# --- a combobox pick is an ordinary input frame
drive_input(d, "e1", "Arizona")
stopifnot(n("ex_out") == 2L)
stopifnot(grepl("Arizona", last("ex_out")))
cat("e1 -> Arizona: one input frame, one re-render\n")

# --- multi stays plural through the same output
drive_input(d, "e2", list("Alaska", "Hawaii"))
stopifnot(grepl("chr \\[1:2\\]", last("ex_out")))
drive_input(d, "e2", list())
stopifnot(grepl("chr\\(0\\)", last("ex_out")))
cat("e2: plural at every length, empty included\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("Selectize OK\n")
