# Native mappings for select, textarea, number, and table_output.

if (!requireNamespace("flitR", quietly = TRUE)) {
    exit_file("flitR not installed")
}
if (!all(c("select", "textarea", "number", "render_dirty") %in%
    getNamespaceExports("flitR"))) {
    exit_file("flitR too old for parity widgets")
}

.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

s <- glinty:::new_session("parity-test")
values <- new.env(parent = emptyenv())

flatten <- function(x) {
    if (is.list(x) && !is.null(x$op)) {
        return(list(x))
    }
    if (is.list(x)) {
        return(do.call(c, c(lapply(x, flatten), list(list()))))
    }
    list()
}
find_hit <- function(ops, id) {
    hits <- Filter(function(o) identical(o$op, "hit") &&
        identical(o$id, id), ops)
    if (length(hits)) hits[[1L]] else NULL
}

flitR_env <- flitR:::.flitR_env
flitR_env$open_select <- NULL

ui <- page(
    select_input("sel", "Choice:",
        choices = c(Alpha = "a", Bravo = "b"), selected = "b"),
    textarea_input("notes", "Notes:", value = "line1", rows = 5L),
    number_input("num", "N:", value = 7),
    table_output("tbl")
)

ops <- flatten(glinty:::build_native_ops(ui, s, values))

# --- select: header hit present, label shows the selected choice ---
sel_hit <- find_hit(ops, "sel")
expect_false(is.null(sel_hit))
texts <- vapply(Filter(function(o) identical(o$op, "text"), ops),
    function(o) o$text, character(1L))
expect_true("Bravo" %in% texts)

# choosing routes through glinty's input handler
sel_hit$on_click() # opens
expect_equal(flitR_env$open_select, "sel")
ops_open <- flatten(glinty:::build_native_ops(ui, s, values))
opt1 <- find_hit(ops_open, "sel_opt1")
expect_false(is.null(opt1))
opt1$on_click()
flush_reactions()
expect_equal(isolate(s$input$sel()), "a")
expect_null(flitR_env$open_select)

# once the input holds a value, the label follows it
ops_after <- flatten(glinty:::build_native_ops(ui, s, values))
texts_after <- vapply(Filter(function(o) identical(o$op, "text"),
    ops_after), function(o) o$text, character(1L))
expect_true("Alpha" %in% texts_after)

# --- textarea: multiline flag, rows sizing, initial value ---
ta_hit <- find_hit(ops, "notes")
expect_false(is.null(ta_hit))
expect_true(isTRUE(ta_hit$input$multiline))
expect_equal(ta_hit$h, 5 * 20 + 12)
expect_equal(ta_hit$input$value, "line1")
ta_hit$input$on_change("line1\nline2")
flush_reactions()
expect_equal(isolate(s$input$notes()), "line1\nline2")

# --- number: filter present, numeric on_change reaches glinty ---
num_hit <- find_hit(ops, "num")
expect_false(is.null(num_hit))
expect_equal(num_hit$input$filter, "numeric")
num_hit$input$on_change("42")
flush_reactions()
expect_equal(isolate(s$input$num()), 42)

# --- table: empty before data, grid after ---
# grid text renders at size 13; none exists before the first update
expect_equal(length(Filter(function(o) identical(o$op, "text") &&
    identical(o$size, 13), ops)), 0L)

values[["tbl"]] <- list(
    header = list("name", "n"),
    rows = list(list("alpha", "1"), list("longer-cell", "22"))
)
ops_tbl <- flatten(glinty:::build_native_ops(ui, s, values))
tbl_texts <- vapply(Filter(function(o) identical(o$op, "text") &&
    o$size == 13, ops_tbl), function(o) o$text, character(1L))
expect_true(all(c("name", "n", "alpha", "longer-cell", "22") %in%
    tbl_texts))
# 3 grid rows x 2 cols x 2 rects each = 12 rects at size-13 text rows
grid_rects <- Filter(function(o) identical(o$op, "rect") &&
    o$h %in% c(24, 22), ops_tbl)
expect_equal(length(grid_rects), 12L)

# --- fail-fast list is now radio/date/file/html/audio only ---
bad <- page(radio_buttons("r", choices = "x"), date_input("d"),
    file_input("f"), html_output("h"), audio_output("a"))
err <- tryCatch(glinty:::build_native_ops(bad, s, values),
    error = function(e) conditionMessage(e))
for (nm in c("radio_buttons", "date_input", "file_input",
    "html_output", "audio_output")) {
    expect_true(grepl(nm, err), info = nm)
}
expect_false(grepl("select_input|textarea_input|number_input|table_output",
    err))

glinty:::session_end(s)
