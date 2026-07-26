# Native handling of the widgets added in 0.4.0. The contract is that
# every one either renders correctly or fails fast by name -- never
# silently renders something wrong.

if (!requireNamespace("flitR", quietly = TRUE)) {
    exit_file("flitR not installed")
}

.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
session_end <- glinty:::session_end
build_native_ops <- glinty:::build_native_ops
native_apply <- glinty:::native_apply
eval_condition <- glinty:::eval_condition
tag_condition <- glinty:::tag_condition
handle_input <- glinty:::handle_input
harvest_native_inputs <- glinty:::harvest_native_inputs

build <- function(ui, session, values = new.env(parent = emptyenv())) {
    build_native_ops(ui, session, values)
}

# Every string in a scene. Walks rather than unlist()ing, because the
# ops carry closures (on_click, on_change) that unlist mangles.
drawn <- function(x) {
    out <- character(0L)
    walk <- function(node) {
        if (is.function(node)) {
            return(invisible(NULL))
        }
        if (is.character(node)) {
            out <<- c(out, node)
            return(invisible(NULL))
        }
        if (is.list(node)) {
            for (el in node) walk(el)
        }
        invisible(NULL)
    }
    walk(x)
    out
}

# --- widgets with no native counterpart fail fast, by their own name
s <- new_session("n1")
expect_error(build(page(download_button("dl", "Get")), s), "download_button")
expect_error(build(page(modal_button("Cancel")), s), "modal_button")

# the message names the widget, not the HTML tag it happens to use
err <- tryCatch(build(page(download_button("dl", "Get")), s),
                error = function(e) conditionMessage(e))
expect_false(grepl("\\ba\\b", err))

# an ordinary link still renders; only download buttons are refused
expect_silent(build(page(a("cornball.ai", "https://cornball.ai")), s))
session_end(s)

# --- password_input renders, masked ---
# flitR draws bullets while the real string stays in R. The value does
# live on in the hit record, which is how editing works, but flitR's
# scene() strips hit ops before the wire -- so what matters is that no
# *text* op carries it.
text_ops <- function(ops) {
    out <- character(0L)
    walk <- function(node) {
        if (is.function(node)) {
            return(invisible(NULL))
        }
        if (is.list(node)) {
            if (identical(node$op, "text")) {
                out <<- c(out, as.character(node$text))
                return(invisible(NULL))
            }
            for (el in node) walk(el)
        }
        invisible(NULL)
    }
    walk(ops)
    out
}

s <- new_session("n1b")
expect_silent(build(page(password_input("key", "Key:")), s))
handle_input(s, "key", "sk-secret-value")
masked <- text_ops(build(page(password_input("key", "Key:")), s))
expect_false(any(grepl("sk-secret-value", masked, fixed = TRUE)))
expect_true(any(grepl("•", masked, fixed = TRUE)))
# one bullet per character, so the caret stays where it belongs
expect_true(any(masked == strrep("•", nchar("sk-secret-value"))))
# an ordinary text input is not masked
handle_input(s, "plain", "hello world")
plain <- text_ops(build(page(text_input("plain", "P:")), s))
expect_true(any(grepl("hello world", plain, fixed = TRUE)))
session_end(s)

# --- tabset renders, showing only the selected panel ---
s <- new_session("n1c")
ui <- page(tabset(
    tab_panel("Text", h1("text panel")),
    tab_panel("Segments", h1("segments panel")),
    id = "results"
))
# the open tab is harvested as state, like the browser's init pass
harvest_native_inputs(ui, s)
expect_equal(isolate(s$input$results()), "Text")

first <- drawn(build(ui, s))
# both tab labels appear in the nav strip
expect_true(any(grepl("^Text$", first)))
expect_true(any(grepl("^Segments$", first)))
# but only the selected panel's body is emitted -- an unselected panel
# is not hidden, it is simply not drawn this frame
expect_true(any(grepl("text panel", first, fixed = TRUE)))
expect_false(any(grepl("segments panel", first, fixed = TRUE)))

# switching the input switches the panel
handle_input(s, "results", "Segments")
second <- drawn(build(ui, s))
expect_true(any(grepl("segments panel", second, fixed = TRUE)))
expect_false(any(grepl("text panel", second, fixed = TRUE)))

# a selection that is not one of the labels falls back rather than
# rendering an empty tabset
handle_input(s, "results", "Nonsense")
expect_true(any(grepl("text panel", drawn(build(ui, s)), fixed = TRUE)))
session_end(s)

# --- a tabset without an id cannot hold a selection, so it says so ---
s <- new_session("n1d")
err3 <- tryCatch(build(page(tabset(tab_panel("A", h1("a")))), s),
                 error = function(e) conditionMessage(e))
expect_true(grepl("tabset without an id", err3, fixed = TRUE))
session_end(s)

# --- verbatim_output renders natively ---
s <- new_session("n2")
vals <- new.env(parent = emptyenv())
vals$raw <- "line one\nline two"
ops <- build(page(verbatim_output("raw")), s, vals)
expect_true(length(ops) >= 2L)
expect_silent(build(page(verbatim_output("raw")), s, vals))
# an output with no value yet is still fine
expect_silent(build(page(verbatim_output("never_set")), s, vals))
session_end(s)

# --- conditional_panel is evaluated server-side ---
s <- new_session("n3")
ui <- page(conditional_panel(
    h1("only for openai"),
    condition = input_is("backend", "openai")
))

# input never set: the panel contributes nothing, and an empty scene
# is not an error
expect_silent(build(ui, s))
hidden <- build(ui, s)

handle_input(s, "backend", "openai")
shown <- build(ui, s)
# the visible version carries strictly more than the hidden one
expect_true(length(unlist(shown)) > length(unlist(hidden)))

handle_input(s, "backend", "chatterbox")
expect_equal(length(unlist(build(ui, s))), length(unlist(hidden)))
session_end(s)

# --- the R evaluator agrees with the client's rules ---
s <- new_session("n4")
cond_is <- tag_condition(conditional_panel(h1("x"),
                                           condition = input_is("b", "openai")))
expect_false(eval_condition(cond_is, s))
handle_input(s, "b", "openai")
expect_true(eval_condition(cond_is, s))
handle_input(s, "b", "other")
expect_false(eval_condition(cond_is, s))

# a vector is an is-one-of test
multi <- tag_condition(conditional_panel(
    h1("x"), condition = input_is("b", c("chatterbox", "native"))
))
handle_input(s, "b", "native")
expect_true(eval_condition(multi, s))
handle_input(s, "b", "qwen3")
expect_false(eval_condition(multi, s))

# logicals compare by truthiness, matching String()/Boolean() on the
# client rather than by string
flag <- tag_condition(conditional_panel(h1("x"),
                                        condition = input_is("save", TRUE)))
handle_input(s, "save", TRUE)
expect_true(eval_condition(flag, s))
handle_input(s, "save", FALSE)
expect_false(eval_condition(flag, s))

# numbers compare as strings, so 3 matches "3"
num <- tag_condition(conditional_panel(h1("x"),
                                       condition = input_is("n", "3")))
handle_input(s, "n", 3L)
expect_true(eval_condition(num, s))

# and, or, not
nested <- tag_condition(conditional_panel(h1("x"), condition = cond_not(
    cond_and(input_is("backend", "qwen3"), input_is("design", TRUE))
)))
handle_input(s, "backend", "qwen3")
handle_input(s, "design", TRUE)
expect_false(eval_condition(nested, s))
handle_input(s, "design", FALSE)
expect_true(eval_condition(nested, s))
handle_input(s, "backend", "openai")
handle_input(s, "design", TRUE)
expect_true(eval_condition(nested, s))

either <- tag_condition(conditional_panel(h1("x"), condition = cond_or(
    input_is("backend", "openai"), input_is("design", TRUE)
)))
expect_true(eval_condition(either, s))

# a malformed or absent condition is FALSE, never an error
expect_false(eval_condition(NULL, s))
expect_false(eval_condition(list(), s))
expect_false(eval_condition(list(op = "bogus"), s))
expect_null(tag_condition(div(h1("no condition here"))))
session_end(s)

# --- browser-only messages are inert natively, not fatal ---
values <- new.env(parent = emptyenv())
native <- new.env(parent = emptyenv())
native$dirty <- FALSE
expect_silent(native_apply('{"type":"modal","action":"show","title":"x"}',
                           values, native))
expect_silent(native_apply('{"type":"progress","action":"show","value":0.5}',
                           values, native))
expect_silent(native_apply('{"type":"custom","handler":"h","value":1}',
                           values, native))
expect_false(native$dirty)
# and a real update still lands
native_apply('{"type":"update","id":"out","property":"textContent","value":"hi"}',
             values, native)
expect_true(native$dirty)
expect_equal(values$out, "hi")
