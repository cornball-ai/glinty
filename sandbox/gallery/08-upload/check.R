# Upload e2e in-process: no file means no table (req), a landed
# file parses under the current controls, and every control
# re-parses. The upload itself is simulated at the input layer with
# the exact data.frame shape the HTTP handler stores.
source("../../tools/drive.R")

d <- drive_boot("app.R", "upload")

n <- function() length(drive_msgs(d, type = "output", id = "contents"))
last <- function() {
    m <- drive_msgs(d, type = "output", id = "contents")
    m[[length(m)]]$value
}

# --- boot: req() keeps the slot silent, and errors stay zero
stopifnot(n() == 0L)
cat("boot: no file, no table, no error\n")

# --- a comma CSV with 8 rows, so head-vs-all is observable
csv <- tempfile(fileext = ".csv")
writeLines(c("x,y", paste(1:8, c("a", "b", "c", "d", "e", "f", "g", "h"),
    sep = ",")), csv)
upload <- data.frame(name = "demo.csv", size = file.size(csv),
    type = "text/csv", datapath = csv, stringsAsFactors = FALSE)
drive_input(d, "file1", upload)
stopifnot(n() == 1L)
stopifnot(identical(unlist(last()$header), c("x", "y")))
stopifnot(length(last()$rows) == 6L)
cat("upload: parsed, head shows 6 of 8\n")

# --- Display = All shows every row
drive_input(d, "disp", "all")
stopifnot(n() == 2L, length(last()$rows) == 8L)
cat("disp -> all: 8 rows\n")

# --- header off makes the header row data
drive_input(d, "header", FALSE)
stopifnot(n() == 3L, length(last()$rows) == 9L)
stopifnot(identical(unlist(last()$rows[[1L]])[[1L]], "x"))
cat("header off: 9 rows, first is x,y\n")

# --- a semicolon file needs the separator control
csv2 <- tempfile(fileext = ".csv")
writeLines(c("a;b", "1;2", "3;4"), csv2)
drive_input(d, "file1", data.frame(name = "semi.csv",
    size = file.size(csv2), type = "text/csv", datapath = csv2,
    stringsAsFactors = FALSE))
drive_input(d, "header", TRUE)
drive_input(d, "sep", ";")
stopifnot(identical(unlist(last()$header), c("a", "b")))
stopifnot(length(last()$rows) == 2L)
cat("semicolon file + sep control: 2x2\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("UPLOAD OK\n")
