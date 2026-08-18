# DataTables e2e in-process: three tables render whole, the column
# picker subsets diamonds server-side, and everything interactive
# (sort/filter/page) is client-side by design -- so from the server's
# seat the tables are just table values of known shape.
source("../../tools/drive.R")

d <- drive_boot("app.R")

last <- function(id) {
    m <- drive_msgs(d, type = "output", id = id)
    m[[length(m)]]$value
}
n <- function(id) length(drive_msgs(d, type = "output", id = id))

# --- boot: all three tables render fully, hidden tabs included
stopifnot(n("mytable1") == 1L, n("mytable2") == 1L, n("mytable3") == 1L)
stopifnot(length(last("mytable1")$rows) == 1000L)
stopifnot(length(last("mytable1")$header) == 10L)
stopifnot(length(last("mytable2")$rows) == 32L)
stopifnot(identical(unlist(last("mytable2")$header)[1L], "model"))
stopifnot(length(last("mytable3")$rows) == 150L)
# align carries the numeric signal the client sorts by
stopifnot(identical(unlist(last("mytable1")$align)[1L], "num"))   # carat
stopifnot(identical(unlist(last("mytable1")$align)[2L], "text"))  # cut
cat("boot: 1000 diamonds x10, 32 cars +model, 150 iris\n")

# --- the tabset seeded its input; conditions key on it
stopifnot(identical(glinty::isolate(d$input$dataset()), "diamonds"))

# --- unchecking columns subsets diamonds; row count holds
drive_input(d, "show_vars", list("carat", "cut", "price"))
stopifnot(n("mytable1") == 2L)
stopifnot(length(last("mytable1")$header) == 3L)
stopifnot(identical(unlist(last("mytable1")$header),
                    c("carat", "cut", "price")))
stopifnot(length(last("mytable1")$rows) == 1000L)
stopifnot(length(last("mytable1")$rows[[1L]]) == 3L)
# the other tables did not re-render
stopifnot(n("mytable2") == 1L, n("mytable3") == 1L)
cat("show_vars -> 3 cols: diamonds re-emitted alone\n")

# --- empty selection is legal and yields a zero-column table
drive_input(d, "show_vars", list())
stopifnot(n("mytable1") == 3L)
stopifnot(length(last("mytable1")$header) == 0L)
cat("show_vars -> none: zero-column table, no error\n")

# --- switching tabs is an input like any other, and re-renders nothing
drive_input(d, "dataset", "iris")
stopifnot(identical(glinty::isolate(d$input$dataset()), "iris"))
stopifnot(n("mytable1") == 3L, n("mytable3") == 1L)
cat("tab -> iris: pure visibility, zero re-renders\n")

stopifnot(length(drive_msgs(d, type = "error")) == 0L)
cat("DataTables OK\n")
