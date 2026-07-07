# Native backend translation tests. Pure: no daemon, no window --
# scene building is side-effect-free until flitR::scene() runs.

if (!requireNamespace("flitR", quietly = TRUE)) {
    exit_file("flitR not installed")
}
if (!all(c("image", "render_dirty") %in% getNamespaceExports("flitR"))) {
    exit_file("flitR too old (needs image op + driver API)")
}

.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

build_native_ops <- glinty:::build_native_ops
native_apply <- glinty:::native_apply

flatten <- function(x) {
    if (is.list(x) && !is.null(x$op)) {
        return(list(x))
    }
    if (is.list(x)) {
        return(do.call(c, c(lapply(x, flatten), list(list()))))
    }
    list()
}
ops_of <- function(ui, session, values) {
    flatten(build_native_ops(ui, session, values))
}
find_op <- function(ops, kind, id = NULL) {
    hits <- Filter(function(o) {
        identical(o$op, kind) && (is.null(id) || identical(o$id, id))
    }, ops)
    if (length(hits)) hits[[1L]] else NULL
}

s <- glinty:::new_session("native-test")
values <- new.env(parent = emptyenv())

ui <- page(
    h1("Native"),
    p("hello native"),
    text_input("name", "Name:", value = "troy"),
    button("go", "Run"),
    checkbox_input("chk", "Enabled", value = TRUE),
    slider_input("sl", "Amount:", min = 0, max = 10, value = 5),
    text_output("greeting"),
    plot_output("plt", width = 300L, height = 200L),
    title = "native"
)

values[["greeting"]] <- "hola troy"
values[["plt"]] <- "data:image/png;base64,QUJDRA=="

ops <- ops_of(ui, s, values)

# headings and text scale by level
h <- Filter(function(o) identical(o$op, "text") &&
    identical(o$text, "Native"), ops)[[1L]]
expect_equal(h$size, 24)

# text_output interpolates the current value
expect_false(is.null(Filter(function(o) identical(o$op, "text") &&
    identical(o$text, "hola troy"), ops)[[1L]]$x))

# widgets carry hit records with callbacks
btn <- find_op(ops, "hit", "go")
expect_false(is.null(btn))
expect_true(is.function(btn$on_click))

inp <- find_op(ops, "hit", "name")
expect_false(is.null(inp))
expect_true(is.function(inp$input$on_change))

sl <- find_op(ops, "hit", "sl")
expect_false(is.null(sl))
expect_equal(sl$slider$min, 0)
expect_equal(sl$slider$max, 10)

# plot becomes an image op with the base64 passed through
img <- Filter(function(o) identical(o$op, "image"), ops)[[1L]]
expect_equal(img$data, "QUJDRA==")
expect_equal(img$w, 300)
expect_equal(img$h, 200)

# before the first render the plot is a placeholder rect
values2 <- new.env(parent = emptyenv())
ops2 <- ops_of(ui, s, values2)
expect_equal(length(Filter(function(o) identical(o$op, "image"), ops2)),
    0L)

# --- callbacks drive glinty's input handlers ---
btn$on_click()
flush_reactions()
expect_equal(isolate(s$input$go()), 1L)

inp$input$on_change("jorge")
flush_reactions()
expect_equal(isolate(s$input$name()), "jorge")

# input value round-trips into the next build
ops3 <- ops_of(ui, s, values)
inp3 <- find_op(ops3, "hit", "name")
expect_equal(inp3$input$value, "jorge")

# --- unsupported widgets fail fast with a list ---
bad_ui <- page(
    select_input("sel", choices = c("a", "b")),
    radio_buttons("r", choices = c("x")),
    table_output("tbl")
)
err <- tryCatch(build_native_ops(bad_ui, s, new.env()),
    error = function(e) conditionMessage(e))
expect_true(grepl("select_input", err))
expect_true(grepl("radio_buttons", err))
expect_true(grepl("table_output", err))

# --- native_apply: protocol messages set values and dirty ---
native <- new.env(parent = emptyenv())
native$dirty <- FALSE
vals <- new.env(parent = emptyenv())

native_apply('{"type":"update","id":"x","property":"textContent","value":"7"}',
    vals, native)
expect_equal(vals[["x"]], "7")
expect_true(native$dirty)

native$dirty <- FALSE
native_apply('{"type":"error","id":"x","message":"boom"}', vals, native)
expect_equal(vals[["x"]], "Error: boom")
expect_true(native$dirty)

native$dirty <- FALSE
native_apply('{"type":"config","session_id":"n","protocol":2}', vals,
    native)
expect_false(native$dirty)

native_apply("{bad json", vals, native)
expect_false(native$dirty)

glinty:::session_end(s)
