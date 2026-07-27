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
        expect_silent(component_to_flitr(f$component, uns))
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
    expect_null(component_to_flitr(bogus, uns))
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
    strings <- drawn(component_to_flitr(tree, uns))
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
                                   uns))
}

# --- icon: browser renders a token, flitR refuses by name ---
ico <- component_to_html(component("icon", name = "play"))
expect_true(grepl("g-icon-play", ico, fixed = TRUE))
expect_true(grepl('data-g-icon="play"', ico, fixed = TRUE))
if (has_flitr) {
    uns <- new_unsupported()
    expect_null(component_to_flitr(component("icon", name = "play"), uns))
    expect_true("icon" %in% uns$names)
}

# --- raw_html: browser renders, flitR refuses by name ---
if (has_flitr) {
    uns <- new_unsupported()
    expect_null(component_to_flitr(component("raw_html", html = "<b>x</b>"),
                                   uns))
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
    expect_error(component_to_flitr("nope", new_unsupported()),
                 "expects a component")
}
