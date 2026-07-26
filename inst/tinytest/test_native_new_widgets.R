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

build <- function(ui, session, values = new.env(parent = emptyenv())) {
    build_native_ops(ui, session, values)
}

# --- widgets with no native counterpart fail fast, by their own name
s <- new_session("n1")
expect_error(build(page(tabset(tab_panel("A", h1("a")))), s), "tabset")
expect_error(build(page(tabset(tab_panel("A", h1("a")), id = "t")), s),
             "tabset")
expect_error(build(page(password_input("key", "Key:")), s), "password_input")
expect_error(build(page(download_button("dl", "Get")), s), "download_button")
expect_error(build(page(modal_button("Cancel")), s), "modal_button")

# the message names the widget, not the HTML tag it happens to use
err <- tryCatch(build(page(download_button("dl", "Get")), s),
                error = function(e) conditionMessage(e))
expect_false(grepl("\\ba\\b", err))
err2 <- tryCatch(build(page(password_input("k", "K")), s),
                 error = function(e) conditionMessage(e))
expect_false(grepl("input\\[type=", err2))

# an ordinary link still renders; only download buttons are refused
expect_silent(build(page(a("cornball.ai", "https://cornball.ai")), s))
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
