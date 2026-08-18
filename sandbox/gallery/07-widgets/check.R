# Widgets e2e in-process: outputs move only on the button. The whole
# check is about what does NOT re-render.
source("../../tools/drive.R")

d <- drive_boot("app.R", "widgets")

n <- function(id) length(drive_msgs(d, type = "output", id = id))
last <- function(id) {
    m <- drive_msgs(d, type = "output", id = id)
    m[[length(m)]]$value
}

# --- boot: ignore_init = FALSE computes the initial dataset (rock),
#     10 rows, summary of the full data
stopifnot(grepl("area", last("summary")))
stopifnot(length(last("view")$rows) == 10L)
s_n <- n("summary")
v_n <- n("view")
cat("boot: rock summary + 10 rows\n")

# --- changing the select does nothing until the button
drive_input(d, "dataset", "pressure")
drive_input(d, "obs", 5)
stopifnot(n("summary") == s_n, n("view") == v_n)
cat("select + obs changed: nothing re-rendered\n")

# --- the button applies both, obs through isolate()
drive_event(d, "update")
stopifnot(n("summary") == s_n + 1L, n("view") == v_n + 1L)
stopifnot(grepl("temperature", last("summary")))
stopifnot(length(last("view")$rows) == 5L)
cat("update: pressure summary + 5 rows\n")

# --- obs alone still gated after the first press
drive_input(d, "obs", 3)
stopifnot(n("view") == v_n + 1L)
drive_event(d, "update")
stopifnot(length(last("view")$rows) == 3L)
cat("obs stays isolated until the next press\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("WIDGETS OK\n")
