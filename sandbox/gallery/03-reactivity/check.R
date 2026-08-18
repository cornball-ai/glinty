# Reactivity e2e in-process: the emission graph IS the lesson.
# dataset feeds summary+view through one shared reactive; caption
# feeds only its heading; obs feeds only the table. An output
# re-emitting when its inputs didn't change is a wiring bug.
source("../../tools/drive.R")

d <- drive_boot("app.R", "reactivity")

n <- function(id) length(drive_msgs(d, type = "output", id = id))
last <- function(id) {
    m <- drive_msgs(d, type = "output", id = id)
    m[[length(m)]]$value
}
counts <- function() c(caption = n("caption_head"), summary = n("summary"),
    view = n("view"))

# --- boot state
stopifnot(n("caption_head") == 1L, n("summary") == 1L, n("view") == 1L)
stopifnot(grepl("Data Summary", jsonlite::toJSON(last("caption_head"))))
stopifnot(grepl("Median", last("summary")))
stopifnot(length(last("view")$rows) == 10L)
cat("boot: three outputs, caption heading, 10 rows\n")

# --- dataset change recomputes summary + view, leaves caption alone
c0 <- counts()
s0 <- last("summary")
drive_input(d, "dataset", "pressure")
c1 <- counts()
stopifnot(c1["caption"] == c0["caption"])
stopifnot(c1["summary"] == c0["summary"] + 1L, c1["view"] == c0["view"] + 1L)
stopifnot(!identical(s0, last("summary")))
cat("dataset -> pressure: summary+view re-emitted, caption untouched\n")

# --- caption change touches only the heading
drive_input(d, "caption", "Pressure readings")
c2 <- counts()
stopifnot(c2["caption"] == c1["caption"] + 1L)
stopifnot(c2["summary"] == c1["summary"], c2["view"] == c1["view"])
stopifnot(grepl("Pressure readings", jsonlite::toJSON(last("caption_head"))))
cat("caption typed: only the heading re-emitted\n")

# --- obs change touches only the table
drive_input(d, "obs", 3)
c3 <- counts()
stopifnot(c3["view"] == c2["view"] + 1L)
stopifnot(c3["caption"] == c2["caption"], c3["summary"] == c2["summary"])
stopifnot(length(last("view")$rows) == 3L)
cat("obs -> 3: only the table re-emitted, 3 rows\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("REACTIVITY OK\n")
