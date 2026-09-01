# Server-side input seeding: the tree is the source of truth.
#
# Protocol 2 asked the client what the initial values were. The
# server built the tree, so v3 answers its own question before the
# client connects: reactives read defaults on their first run, and
# nothing spurious crosses the wire.

.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

new_session <- glinty:::new_session
session_end <- glinty:::session_end
seed_session_inputs <- glinty:::seed_session_inputs
collect_input_seeds <- glinty:::collect_input_seeds
component <- glinty:::component

ui <- page(
    text_input("name", "Name:", value = "seeded"),
    text_input("blank", "Blank:"),
    password_input("secret", "Key:"),
    textarea_input("notes", "Notes:", value = "line1"),
    number_input("n", "N:", value = 7),
    number_input("n_empty", "N2:"),
    checkbox_input("save", "Save", value = TRUE),
    checkbox_input("off", "Off"),
    radio_buttons("mode", "Mode:", c(Fast = "fast", Slow = "slow")),
    checkbox_group("tops", "Toppings:", c(A = "a", B = "b", C = "c"),
                   selected = c("a", "c")),
    checkbox_group("tops_none", "None:", c(A = "a", B = "b")),
    slider_input("sl", "S:", min = 0, max = 100, value = 25),
    slider_input("sl_default", "S2:", min = 10, max = 20),
    range_slider("rng", "R:", min = 1, max = 1000, value = c(200, 500)),
    range_slider("rng_default", "R2:", min = 5, max = 50),
    select_input("engine", "E:", c(A = "a", B = "b")),
    select_input("engine_sel", "E2:", c(A = "a", B = "b"), selected = "b"),
    select_input("multi", "M:", c(A = "a", B = "b"), multiple = TRUE),
    select_input("multi_sel", "M2:", c(A = "a", B = "b"),
                 selected = c("a", "b"), multiple = TRUE),
    date_input("when", "When:", value = "2026-07-27"),
    date_input("when_empty", "When2:"),
    file_input("upload", "File:"),
    button("go", "Go"),
    row(text_input("nested", "In a row:", value = "deep")),
    conditional_panel(
        text_input("hidden_field", "Hidden:", value = "still-seeds"),
        condition = input_is("mode", "slow")
    ),
    tabset(
        id = "tabs",
        tab_panel("First", text_input("in_tab", "T:", value = "tabbed")),
        tab_panel("Second", txt("nothing here"))
    ),
    title = "Seed test"
)

s <- new_session("seed1")
seed_session_inputs(s, ui)

# text-like inputs: value, or "" -- what an empty rendered field shows
expect_equal(isolate(s$input$name()), "seeded")
expect_equal(isolate(s$input$blank()), "")
expect_equal(isolate(s$input$secret()), "")
expect_equal(isolate(s$input$notes()), "line1")
expect_equal(isolate(s$input$when()), "2026-07-27")
expect_equal(isolate(s$input$when_empty()), "")

# a number field can be empty; the input stays NULL then
expect_equal(isolate(s$input$n()), 7)
expect_null(isolate(s$input$n_empty()))

# logicals
expect_true(isolate(s$input$save()))
expect_false(isolate(s$input$off()))

# radio_buttons() guarantees a selection: the first choice
expect_equal(isolate(s$input$mode()), "fast")

# a checkbox group seeds the plural selection; empty is character(0),
# not NULL -- the multiple-select rule
expect_equal(isolate(s$input$tops()), c("a", "c"))
expect_identical(isolate(s$input$tops_none()), character(0))

# sliders always have a position; the builder default is the HTML
# midpoint, so every frontend starts the thumb in the same place
expect_equal(isolate(s$input$sl()), 25)
expect_equal(isolate(s$input$sl_default()), 15)

# a range seeds the numeric pair, not the list the wire carries;
# omitted it spans the whole range
expect_equal(isolate(s$input$rng()), c(200, 500))
expect_equal(isolate(s$input$rng_default()), c(5, 50))

# a single select shows its first choice; a multiple select shows an
# empty selection, which is character(0) and not NULL. The browser
# harvests Array.from(el.selectedOptions) and gets [], so seeding
# NULL made the server disagree with the client it is mirroring
# before anyone had touched anything.
expect_equal(isolate(s$input$engine()), "a")
expect_equal(isolate(s$input$engine_sel()), "b")
expect_equal(isolate(s$input$multi()), character(0))
expect_false(is.null(isolate(s$input$multi())))
expect_equal(isolate(s$input$multi_sel()), c("a", "b"))

# no state to seed: files and events
expect_null(isolate(s$input$upload()))
expect_null(isolate(s$input$go()))

# nesting: rows, hidden conditional panels and tab panels all seed --
# hiding is display, not existence
expect_equal(isolate(s$input$nested()), "deep")
expect_equal(isolate(s$input$hidden_field()), "still-seeds")
expect_equal(isolate(s$input$in_tab()), "tabbed")

# a tabset with an id seeds its selection with the shown panel
expect_equal(isolate(s$input$tabs()), "First")

session_end(s)

# --- tabset selected wins when it names a real panel ---
ts <- tabset(id = "t2", selected = "B",
             tab_panel("A", txt("a")), tab_panel("B", txt("b")))
seeds <- collect_input_seeds(ts)
expect_equal(seeds$t2, "B")
# and falls back to the first panel when it does not
ts_bad <- component("tabset", id = "t3", selected = "Nope",
                    panels = list(list(title = "A", children = list()),
                                  list(title = "B", children = list())))
expect_equal(collect_input_seeds(ts_bad)$t3, "A")
# a tree node with panels but no id (not constructible through
# tabset(), which requires one) seeds nothing rather than erroring
expect_equal(collect_input_seeds(list(component = "tabset",
    panels = list(list(title = "A", children = list())))), list())

# --- seeding runs before the server function, so observe_event with ---
# --- ignore_init stays quiet: init state is not a change ---
s2 <- new_session("seed2")
seed_session_inputs(s2, page(
    select_input("backend", "B:", c(X = "x", Y = "y")),
    checkbox_input("chk", "C", value = TRUE),
    title = "quiet"
))
fired <- 0L
glinty:::with_session(s2, {
    observe_event(s2$input$backend, function() fired <<- fired + 1L)
    observe_event(s2$input$chk, function() fired <<- fired + 1L)
})
flush_reactions()
expect_equal(fired, 0L)

# and a real change still fires
glinty:::handle_input(s2, "backend", "y")
flush_reactions()
expect_equal(fired, 1L)

# while a plain reactive sees the seeded default on its first run,
# not NULL followed by a re-render
seen_first <- NULL
glinty:::with_session(s2, {
    observe(function() {
        if (is.null(seen_first)) seen_first <<- s2$input$chk()
    })
})
flush_reactions()
expect_true(seen_first)

session_end(s2)

# --- duplicate ids: first wins, deterministically ---
dup <- page(text_input("x", "A:", value = "first"),
            text_input("x", "B:", value = "second"),
            title = "dup")
s3 <- new_session("seed3")
seed_session_inputs(s3, dup)
expect_equal(isolate(s3$input$x()), "first")
session_end(s3)

# --- a selectable data table is an input; a plain one is not ---
#
# The tabset shape: an id-keyed input outside INPUT_META, seeded from
# the tree. Nothing selected is character(0), the multiple-select
# rule, so `df[input$runs(), ]` is a zero-row frame rather than an
# error. A table with no selection mode seeds nothing and stays
# auto-NULL, like any output.
seed_of <- glinty:::input_seed_value
expect_null(seed_of(data_table("g")))
expect_identical(seed_of(data_table("g", selection = "single")), character(0))
expect_identical(seed_of(data_table("g", selection = "multiple")), character(0))

s4 <- new_session("seed4")
seed_session_inputs(s4, page(data_table("runs", selection = "multiple"),
                             data_table("plain"), title = "tables"))
expect_identical(isolate(s4$input$runs()), character(0))
expect_null(isolate(s4$input$plain()))

# keys arrive as a JSON array and land as a character vector, through
# the live dispatch (and so through normalize_value); the empty array
# is the seed's state again, not NULL
glinty:::dispatch_client_message(s4,
    '{"type":"input","id":"runs","value":["2","5"]}')
expect_identical(isolate(s4$input$runs()), c("2", "5"))
glinty:::dispatch_client_message(s4,
    '{"type":"input","id":"runs","value":["r-79da5a3068b1583a"]}')
expect_identical(isolate(s4$input$runs()), "r-79da5a3068b1583a")
glinty:::dispatch_client_message(s4, '{"type":"input","id":"runs","value":[]}')
expect_identical(isolate(s4$input$runs()), character(0))
session_end(s4)
