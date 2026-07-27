# Both lowerings, asserted against the same fixtures.
#
# A component only counts as frontend-neutral once more than one
# lowering has had to render it. This file is where that stops being
# an intention.

component <- glinty:::component
component_fixtures <- glinty:::component_fixtures
component_to_html <- glinty:::component_to_html
html_el <- glinty:::html_el

has_flitr <- requireNamespace("flitR", quietly = TRUE)
if (has_flitr) {
    component_to_flitr <- glinty:::component_to_flitr
}
new_unsupported <- function() {
    e <- new.env(parent = emptyenv())
    e$names <- character(0L)
    e
}

# A session for the flitR lowering, which needs somewhere to report
# input changes. Reset per use so assertions do not see stale values.
new_test_session <- local({
    n <- 0L
    function() {
        n <<- n + 1L
        glinty:::new_session(paste0("lower", n))
    }
})
s <- new_test_session()

# Every string in a flitR op tree. Walks rather than unlist()ing,
# because ops carry closures that unlist mangles.
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

# --- every fixture lowers to HTML without error ---
for (f in component_fixtures()) {
    html <- component_to_html(f$component)
    expect_true(is.character(html) && length(html) == 1L)
    # only the empty container may render to nothing
    if (!identical(f$name, "empty-column")) {
        expect_true(nzchar(html))
    }
}

# --- every fixture lowers to flitR, or is refused by name ---
if (has_flitr) {
    for (f in component_fixtures()) {
        uns <- new_unsupported()
        expect_silent(component_to_flitr(f$component, s, uns))
        # a refusal names the component; it never approximates
        if (length(uns$names) > 0L) {
            expect_true(all(nzchar(uns$names)))
        }
    }
}

# --- static content, both sides ---
expect_true(grepl(">hello<", component_to_html(component("text",
                                                         value = "hello")),
                  fixed = TRUE))
expect_true(grepl("g-muted", component_to_html(component("text", value = "x",
                                                         variant = "muted")),
                  fixed = TRUE))

# heading level is a number, and becomes h1..h4 only in the browser
h <- component_to_html(component("heading", value = "Title", level = 1L))
expect_true(grepl("<h1", h, fixed = TRUE))
expect_true(grepl("</h1>", h, fixed = TRUE))
expect_true(grepl("<h3", component_to_html(component("heading", value = "x",
                                                     level = 3L)),
                  fixed = TRUE))

# external links carry rel, internal ones do not
ext <- component_to_html(component("link", value = "a", href = "https://x",
                                   external = TRUE))
expect_true(grepl("noopener", ext, fixed = TRUE))
expect_true(grepl('target="_blank"', ext, fixed = TRUE))
expect_false(grepl("noopener",
                   component_to_html(component("link", value = "a",
                                               href = "/x")),
                   fixed = TRUE))

# --- values are escaped on the way out ---
nasty <- component("text", value = '<script>alert("x")</script>')
out <- component_to_html(nasty)
expect_false(grepl("<script>", out, fixed = TRUE))
expect_true(grepl("&lt;script&gt;", out, fixed = TRUE))

expect_false(grepl("<b>", component_to_html(component("heading",
                                                      value = "<b>hi</b>")),
                   fixed = TRUE))
expect_false(grepl('"><script',
                   component_to_html(component("link", value = "x",
                                               href = '"><script>')),
                   fixed = TRUE))

# raw_html is the one component that is deliberately not escaped
expect_equal(component_to_html(component("raw_html",
                                         html = "<details>x</details>")),
             "<details>x</details>")

# --- an unknown component is visible, not silent ---
# Constructed by hand, since component() would refuse the type.
bogus <- structure(list(component = "from_the_future", value = "x"),
                   class = "glinty_component")
ghost <- component_to_html(bogus)
expect_true(grepl("g-unsupported", ghost, fixed = TRUE))
expect_true(grepl("from_the_future", ghost, fixed = TRUE))

if (has_flitr) {
    uns <- new_unsupported()
    expect_null(component_to_flitr(bogus, s, uns))
    expect_true("from_the_future" %in% uns$names)
}

# --- layout nests on both sides ---
tree <- component("column", gap = 4L, children = list(
    component("heading", value = "Section"),
    component("row", gap = 8L, children = list(
        component("text", value = "x"),
        component("text", value = "y")
    ))
))
html <- component_to_html(tree)
expect_true(grepl("g-layout-col", html, fixed = TRUE))
expect_true(grepl("g-layout-row", html, fixed = TRUE))
expect_true(grepl("gap:4px", html, fixed = TRUE))
expect_true(grepl("gap:8px", html, fixed = TRUE))
# both leaves survive the nesting
expect_true(grepl(">x<", html, fixed = TRUE))
expect_true(grepl(">y<", html, fixed = TRUE))

if (has_flitr) {
    uns <- new_unsupported()
    strings <- drawn(component_to_flitr(tree, s, uns))
    expect_true("Section" %in% strings)
    expect_true("x" %in% strings)
    expect_true("y" %in% strings)
    expect_equal(length(uns$names), 0L)
}

# --- an empty container is not a crash ---
expect_silent(component_to_html(component("column", children = list())))
if (has_flitr) {
    uns <- new_unsupported()
    expect_null(component_to_flitr(component("column", children = list()),
                                   s, uns))
}

# --- icon: browser renders a token, flitR refuses by name ---
ico <- component_to_html(component("icon", name = "play"))
expect_true(grepl("g-icon-play", ico, fixed = TRUE))
expect_true(grepl('data-g-icon="play"', ico, fixed = TRUE))
if (has_flitr) {
    uns <- new_unsupported()
    expect_null(component_to_flitr(component("icon", name = "play"), s, uns))
    expect_true("icon" %in% uns$names)
}

# --- raw_html: browser renders, flitR refuses by name ---
if (has_flitr) {
    uns <- new_unsupported()
    expect_null(component_to_flitr(component("raw_html", html = "<b>x</b>"),
                                   s, uns))
    expect_true("raw_html" %in% uns$names)
}

# --- html_el drops NULL attributes rather than emitting empty ones ---
expect_equal(html_el("div", list(class = "a", id = NULL), "x"),
             '<div class="a">x</div>')
expect_equal(html_el("hr", list(), void = TRUE), "<hr>")
expect_true(grepl("&quot;",
                  html_el("div", list(title = 'say "hi"'), ""),
                  fixed = TRUE))

# --- a lowering refuses a non-component outright ---
expect_error(component_to_html("a bare string"), "expects a component")
expect_error(component_to_html(list(component = "text")), "expects a component")
if (has_flitr) {
    expect_error(component_to_flitr("nope", s, new_unsupported()),
                 "expects a component")
}

# --- input conformance: both lowerings agree on the message ---
#
# The real question for an input is not "does it render" but "when the
# user changes it, what reaches the server". Rendering can differ;
# the outbound message must not.
#
# The browser's handler lives in JS and cannot be invoked from R, so
# this asserts the two halves that are checkable: the HTML declares the
# right target and message type, and flitR's callback actually delivers
# that pair to the session.

INPUT_META <- glinty:::INPUT_META
handle_input <- glinty:::handle_input
session_end <- glinty:::session_end

# flitR exposes a change callback differently per widget: text-like
# widgets through hit$input$on_change, sliders through
# hit$slider$on_change, and checkboxes through on_click, which
# toggles. That is flitR API shape rather than a component concern,
# but a conformance test has to know it to poke each widget.
poke <- function(widget, value) {
    hits <- Filter(function(o) identical(o$op, "hit"), widget)
    for (h in hits) {
        if (!is.null(h$input$on_change)) {
            h$input$on_change(value)
            return(TRUE)
        }
        if (!is.null(h$slider$on_change)) {
            h$slider$on_change(value)
            return(TRUE)
        }
        if (!is.null(h$on_click)) {
            h$on_click()
            return(TRUE)
        }
    }
    FALSE
}

# one representative per value type, with the value a user would produce
cases <- list(
    list(comp = component("text_input", id = "name"), user = "Troy",
         expect = "Troy"),
    list(comp = component("password_input", id = "key"), user = "sk-x",
         expect = "sk-x"),
    list(comp = component("textarea_input", id = "notes"), user = "line",
         expect = "line"),
    list(comp = component("number_input", id = "n"), user = 42, expect = 42),
    list(comp = component("select_input", id = "backend",
                          choices = c(OpenAI = "openai", Local = "local")),
         user = "local", expect = "local"),
    list(comp = component("checkbox_input", id = "save"), user = TRUE,
         expect = TRUE),
    list(comp = component("slider_input", id = "speed", min = 0, max = 2),
         user = 1.5, expect = 1.5)
)

for (case in cases) {
    x <- case$comp
    name <- x$component
    meta <- INPUT_META[[name]]
    expect_true(!is.null(meta))

    # the HTML declares who it reports to and as what
    html <- component_to_html(x)
    expect_true(grepl(paste0('data-g-target="', x$id, '"'), html,
                      fixed = TRUE))
    expect_true(grepl(paste0('data-g-message="', meta$message, '"'), html,
                      fixed = TRUE))

    # emit intent becomes a DOM event name only here
    if (!is.null(x$emit)) {
        want <- if (identical(x$emit, "live")) "input" else "change"
        expect_true(grepl(paste0('data-g-event="', want, '"'), html,
                          fixed = TRUE))
    }

    # and flitR delivers the same (id, value) to the session
    if (has_flitr && !identical(name, "select_input")) {
        sess <- new_test_session()
        uns <- new_unsupported()
        widget <- component_to_flitr(x, sess, uns)
        if (length(uns$names) == 0L) {
            expect_true(!is.null(widget))
            expect_true(poke(widget, case$user))
            expect_equal(glinty::isolate(sess$input[[x$id]]()), case$expect)
        }
        session_end(sess)
    }
}

# a button emits an event, not an input, on both sides
btn_html <- component_to_html(component("button", id = "go", label = "Run"))
expect_true(grepl('data-g-message="event"', btn_html, fixed = TRUE))
expect_true(grepl('data-g-target="go"', btn_html, fixed = TRUE))
# and carries no emit intent, because it has no value to report live
expect_false(grepl("data-g-event=", btn_html, fixed = TRUE))

# --- password_input cannot render a value, because it has no field ---
expect_error(component("password_input", id = "k", value = "sk-secret"),
             "unknown field")
pw <- component_to_html(component("password_input", id = "k",
                                  label = "API Key"))
expect_true(grepl('type="password"', pw, fixed = TRUE))
expect_true(grepl('value=""', pw, fixed = TRUE))

# --- emit is intent, and the frontends spend it differently ---
# The browser honours settle; flitR has no live/settle distinction at
# all and reports on every keystroke. Recorded rather than pretended
# away: a component may be renderable on both and still behave
# differently, and the schema is where that is decided.
live <- component_to_html(component("text_input", id = "a", emit = "live"))
settle <- component_to_html(component("text_input", id = "b",
                                      emit = "settle"))
expect_true(grepl('data-g-event="input"', live, fixed = TRUE))
expect_true(grepl('data-g-event="change"', settle, fixed = TRUE))

# --- choices normalize identically however they were written ---
named <- component("select_input", id = "s", choices = c(Fast = "fast"))
bare <- component("select_input", id = "s", choices = "fast")
expect_equal(named$choices[[1]]$value, "fast")
expect_equal(named$choices[[1]]$label, "Fast")
expect_equal(bare$choices[[1]]$label, "fast")
expect_error(component("select_input", id = "s", choices = list(list(x = 1))),
             "must have both a value and a label")
expect_error(component("select_input", id = "s", choices = character(0)),
             "non-empty")

# --- inputs flitR has no widget for are refused by name ---
if (has_flitr) {
    for (nm in c("radio_buttons", "date_input", "file_input")) {
        sess <- new_test_session()
        uns <- new_unsupported()
        comp <- switch(nm,
            radio_buttons = component("radio_buttons", id = "r",
                                      choices = c("a", "b")),
            date_input = component("date_input", id = "d"),
            file_input = component("file_input", id = "f"))
        expect_null(component_to_flitr(comp, sess, uns))
        expect_true(nm %in% uns$names)
        session_end(sess)
    }
}

# --- every input in INPUT_META lowers to HTML ---
# Adding one to the schema without teaching the browser about it fails
# here rather than in a running app.
for (nm in names(INPUT_META)) {
    args <- list(nm, id = "probe")
    if (nm %in% c("select_input", "radio_buttons")) {
        args$choices <- c("a", "b")
    }
    if (identical(nm, "slider_input")) {
        args$min <- 0
        args$max <- 1
    }
    if (identical(nm, "button")) {
        args$label <- "Go"
    }
    out <- component_to_html(do.call(component, args))
    expect_false(grepl("g-unsupported", out, fixed = TRUE))
}
