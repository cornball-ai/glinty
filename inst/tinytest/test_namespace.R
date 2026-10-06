# Namespaces: keeping independently written subtrees apart on a page
# whose ids are global, and app() refusing the collision a page would
# otherwise ship silently.

.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
session_end <- glinty:::session_end
with_session <- glinty:::with_session
handle_input <- glinty:::handle_input
last_msg <- function(s) jsonlite::fromJSON(s$outgoing[[length(s$outgoing)]])

# --- namespace(): an id builder ---
ns <- namespace("stt")
expect_true(inherits(ns, "glinty_namespace"))
expect_equal(ns("file"), "stt_file")
expect_equal(ns(c("go", "stop")), c("stt_go", "stt_stop"))
expect_equal(ns(), "stt_")
inner <- namespace("logs", parent = ns)
expect_equal(inner("tail"), "stt_logs_tail")
expect_equal(inner(), "stt_logs_")
expect_error(namespace("bad name"), "one word")
expect_error(namespace("1st"), "one word")
expect_error(namespace(""), "one word")
expect_error(namespace("a", parent = "stt_"), "parent must")
expect_error(ns(""), "non-empty")
expect_error(ns(NA_character_), "non-empty")
expect_stdout(print(ns), "stt_")

# --- component_ids(): every id, named by kind, panels included ---
tree <- page(
    text_input("name", "Name:"),
    button("go", "Go"),
    shortcut("go", key = "enter"),
    tabset(
        tab_panel("A", text_output("a")),
        tab_panel("B", collapse(data_table("rows"), title = "Rows")),
        id = "tabs"
    ),
    conditional_panel(download_button("report", "Report"),
                      condition = input_is("name", "x")),
    row(text_output("deep"), id = "r1")
)
ids <- component_ids(tree)
expect_equal(unname(ids),
             c("name", "go", "go", "tabs", "a", "rows", "report", "r1", "deep"))
expect_equal(names(ids),
             c("text_input", "button", "shortcut", "tabset", "text_output",
               "data_table", "download_button", "row", "text_output"))
expect_equal(component_ids(txt("no id")), character(0L))
expect_equal(component_ids("not a tree"), character(0L))
# the unclassed wire form walks the same
expect_equal(unname(component_ids(glinty:::unclass_recursive(tree))),
             unname(ids))

# --- app() refuses a tree where one id names two things ---
srv <- function(input, output) NULL
expect_error(app(page(text_input("x"), text_output("x")), srv),
             "more than once")
expect_error(app(page(text_input("x"), text_input("x")), srv), "x")
expect_error(app(page(tabset(tab_panel("A", text_output("o")), id = "t"),
                      text_output("o")), srv),
             "more than once")
expect_error(app(page(row(id = "box"), column(id = "box")), srv),
             "more than once")
# emitters may share an id: a Save button and its ctrl+s, two Save
# buttons top and bottom
expect_true(inherits(app(page(button("save", "Save"),
                              shortcut("save", key = "ctrl+s"),
                              button("save", "Save")), srv),
                     "glinty_app"))
# but an emitter's id is never also a value's or an output's
expect_error(app(page(button("x", "X"), text_output("x")), srv),
             "both an event")
expect_error(app(page(download_button("x", "X"), text_input("x")), srv),
             "both an event")
# the bundled examples still build
for (ex in c("clock", "counter", "gallery", "jobs")) {
    f <- system.file("examples", ex, "app.R", package = "glinty")
    expect_true(inherits(source(f, local = new.env())$value, "glinty_app"),
                info = ex)
}

# --- scoped(): proxies under which bare ids mean prefixed ones ---
s <- new_session("ns1")
sc <- scoped(ns, s$input, s$output, s)
expect_true(inherits(sc$input, "glinty_input"))
expect_true(inherits(sc$output, "glinty_output"))
expect_true(inherits(sc$session, "glinty_session"))
expect_identical(sc$session$ns, ns)
expect_identical(sc$session$id, "ns1")
expect_identical(glinty:::real_session(sc$session), s)
expect_stdout(print(sc$session), "stt_")

with_session(s, {
    sc$output$greeting <- render_text(function() {
        paste("hi", sc$input$name())
    })
})
flush_reactions()
m <- last_msg(s)
expect_equal(m$id, "stt_greeting")
expect_equal(m$value, "hi ")
# the input the renderer read is the prefixed one
handle_input(s, "stt_name", "troy")
flush_reactions()
expect_equal(last_msg(s)$value, "hi troy")
expect_equal(sc$input$name(), "troy")
expect_equal(sc$input[["name"]](), "troy")
expect_equal(s$input$stt_name(), "troy")
# [[<- on the scoped output too
with_session(s, {
    sc$output[["n"]] <- render_text(function() "1")
})
flush_reactions()
expect_equal(last_msg(s)$id, "stt_n")

# the session proxy's own input and output are scoped as well
expect_equal(sc$session$input$name(), "troy")
with_session(s, {
    sc$session$output$via <- render_text(function() "v")
})
flush_reactions()
expect_equal(last_msg(s)$id, "stt_via")

# the helpers that take (session, id) prefix it
download_handler(sc$session, "md", filename = "a.md",
                 content = function(file) writeLines("x", file))
expect_true(!is.null(s$downloads[["stt_md"]]))
expect_null(s$downloads[["md"]])

update_text_input(sc$session, "name", value = "jorge")
m <- last_msg(s)
expect_equal(m$type, "input_update")
expect_equal(m$id, "stt_name")
expect_equal(s$input$stt_name(), "jorge")

update_video(sc$session, "clip", playing = TRUE)
expect_equal(last_msg(s)$id, "stt_clip")

feed_append(sc$session, "log", txt("one"))
m <- last_msg(s)
expect_equal(m$type, "feed")
expect_equal(m$id, "stt_log")
feed_reset(sc$session, "log")
expect_equal(last_msg(s)$id, "stt_log")

# path_picker() binds its derived ids under the prefix, once
with_session(s, {
    pk <- path_picker(sc$session, sc$input, "proj", kind = "dir",
                      root = tempdir())
})
expect_true(exists("stt_proj_go", envir = s$input_env))
expect_true(exists("stt_proj_choose", envir = s$input_env))
expect_false(exists("stt_stt_proj_go", envir = s$input_env))
expect_false(exists("proj_go", envir = s$input_env))

# writes through the proxy land on the real session
sc$session$note <- "kept"
expect_equal(s$note, "kept")
sc$session[["note2"]] <- "also"
expect_equal(s$note2, "also")

# observers made under the proxy belong to the real session, so
# ending it destroys them
before <- length(s$observers)
with_session(sc$session, {
    observe(function() sc$input$name())
})
expect_equal(length(s$observers), before + 1L)
s$outgoing <- list()
session_end(s)
handle_input(s, "stt_name", "ghost")
flush_reactions()
expect_equal(length(s$outgoing), 0L)

# --- nesting: scoping starts from the real session every time ---
s2 <- new_session("ns2")
outer <- scoped(ns, s2$input, s2$output, s2)
nested <- scoped(namespace("logs", parent = ns), outer$input, outer$output,
                 outer$session)
with_session(s2, {
    nested$output$tail <- render_text(function() "t")
})
flush_reactions()
expect_equal(last_msg(s2)$id, "stt_logs_tail")
expect_identical(glinty:::real_session(nested$session), s2)
session_end(s2)

# --- refusals ---
expect_error(scoped("stt", s$input, s$output, s), "ns must")
expect_error(scoped(ns, list(), s$output, s), "input must")
expect_error(scoped(ns, s$input, list(), s), "output must")
expect_error(scoped(ns, s$input, s$output, list()), "session must")
