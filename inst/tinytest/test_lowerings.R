# The browser lowering, asserted against the shared fixtures.
#
# The second consumer of these fixtures is dart/glinty_flutter, which
# reads the same inst/fixtures/components.json and renders it as
# Flutter widgets. Same repo, same commit, so there is no copy to
# drift -- but still another language, and a second lowering is the
# only thing that proves a component is frontend-neutral rather than
# HTML wearing a component's name.
#
# Adding a fixture here obliges the Dart suite to answer for it.

component <- glinty:::component
component_fixtures <- glinty:::component_fixtures
component_to_html <- glinty:::component_to_html
html_el <- glinty:::html_el
INPUT_META <- glinty:::INPUT_META
OUTPUT_KINDS <- glinty:::OUTPUT_KINDS

# --- every fixture lowers to HTML without error ---
for (f in component_fixtures()) {
    html <- component_to_html(f$component)
    expect_true(is.character(html) && length(html) == 1L)
    # only the empty container may render to nothing
    if (!f$name %in% c("empty-column")) {
        expect_true(nzchar(html))
    }
}

# --- static content ---
expect_true(grepl(">hello<", component_to_html(component("text",
                                                         value = "hello")),
                  fixed = TRUE))
expect_true(grepl("g-muted", component_to_html(component("text", value = "x",
                                                         variant = "muted")),
                  fixed = TRUE))

# heading level is a number, and becomes h1..h4 only here
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

# --- layout nests ---
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
expect_true(grepl(">x<", html, fixed = TRUE))
expect_true(grepl(">y<", html, fixed = TRUE))

# --- an empty container is not a crash ---
expect_silent(component_to_html(component("column", children = list())))

# --- icon renders a token; the frontend owns the artwork ---
ico <- component_to_html(component("icon", name = "play"))
expect_true(grepl("g-icon-play", ico, fixed = TRUE))
expect_true(grepl('data-g-icon="play"', ico, fixed = TRUE))

# --- html_el drops NULL attributes rather than emitting empty ones ---
expect_equal(html_el("div", list(class = "a", id = NULL), "x"),
             '<div class="a">x</div>')
expect_equal(html_el("hr", list(), void = TRUE), "<hr>")
expect_true(grepl("&quot;",
                  html_el("div", list(title = 'say "hi"'), ""),
                  fixed = TRUE))

# --- the lowering refuses a non-component outright ---
expect_error(component_to_html("a bare string"), "expects a component")
expect_error(component_to_html(list(component = "text")), "expects a component")

# --- inputs declare who they report to and as what ---
#
# The browser's handler lives in JS and cannot be invoked from R, so
# this asserts the declaration. The behavioural half -- that a change
# actually reaches the server -- is asserted in glinty-dart, where the
# callback can be fired directly.
for (nm in names(INPUT_META)) {
    args <- list(nm, id = "probe")
    if (nm %in% c("select_input", "radio_buttons", "checkbox_group")) {
        args$choices <- c("a", "b")
    }
    if (nm %in% c("slider_input", "range_slider")) {
        args$min <- 0
        args$max <- 1
    }
    if (identical(nm, "button")) {
        args$label <- "Go"
    }
    if (identical(nm, "shortcut")) {
        args$key <- "k"
    }
    x <- do.call(component, args)
    out <- component_to_html(x)

    # adding an input to the schema without teaching the browser about
    # it fails here rather than in a running app
    expect_false(grepl("g-unsupported", out, fixed = TRUE))
    expect_true(grepl('data-g-target="probe"', out, fixed = TRUE))
    expect_true(grepl(paste0('data-g-message="', INPUT_META[[nm]]$message,
                             '"'),
                      out, fixed = TRUE))
}

# emit intent becomes a DOM event name here and nowhere else
live <- component_to_html(component("text_input", id = "a", emit = "live"))
settle <- component_to_html(component("text_input", id = "b",
                                      emit = "settle"))
expect_true(grepl('data-g-event="input"', live, fixed = TRUE))
expect_true(grepl('data-g-event="change"', settle, fixed = TRUE))

# a button emits an event and carries no emit intent: nothing to report
btn <- component_to_html(component("button", id = "go", label = "Run"))
expect_true(grepl('data-g-message="event"', btn, fixed = TRUE))
expect_false(grepl("data-g-event=", btn, fixed = TRUE))

# --- password_input cannot render a value, because it has no field ---
expect_error(component("password_input", id = "k", value = "sk-secret"),
             "unknown field")
pw <- component_to_html(component("password_input", id = "k",
                                  label = "API Key"))
expect_true(grepl('type="password"', pw, fixed = TRUE))
expect_true(grepl('value=""', pw, fixed = TRUE))

# --- a multiple select's selections all render selected ---
#
# The lowering compared ch$value against x$selected with identical(),
# which against a list is always FALSE: an app could choose three
# options and the served page would show none of them chosen.
multi <- component_to_html(component("select_input", id = "tags",
                                     choices = c("a", "b", "c"),
                                     selected = c("a", "c"),
                                     multiple = TRUE))
expect_equal(length(gregexpr('selected="selected"', multi)[[1]]), 2L)
expect_true(grepl('<option value="a" selected="selected">', multi,
                  fixed = TRUE))
expect_true(grepl('<option value="c" selected="selected">', multi,
                  fixed = TRUE))
expect_true(grepl('<option value="b">', multi, fixed = TRUE))
expect_true(grepl('multiple="multiple"', multi, fixed = TRUE))

# and a single select still marks exactly the one
single <- component_to_html(component("select_input", id = "s",
                                      choices = c("a", "b"),
                                      selected = "b"))
expect_true(grepl('<option value="b" selected="selected">', single,
                  fixed = TRUE))
expect_false(grepl('<option value="a" selected="selected">', single,
                   fixed = TRUE))

# --- modal_button() carries the close mark and no event binding ---
#
# Both halves. Without the mark, the client's delegation never fires
# and the button renders and does nothing -- the same dead control
# the download button was. With the event binding still attached, a
# Cancel would also report, which is the one thing modal_button()
# exists not to do.
cancel <- component_to_html(glinty::modal_button("Cancel"))
expect_true(grepl('data-g-modal-close="1"', cancel, fixed = TRUE))
expect_false(grepl("data-g-message", cancel, fixed = TRUE))
expect_false(grepl("data-g-target", cancel, fixed = TRUE))
expect_true(grepl(">Cancel<", cancel, fixed = TRUE))

# an ordinary button is untouched: it reports, and carries no mark
plain <- component_to_html(component("button", id = "go", label = "Run"))
expect_true(grepl('data-g-message="event"', plain, fixed = TRUE))
expect_false(grepl("data-g-modal-close", plain, fixed = TRUE))

# --- v3.1: how a container takes space in its parent ---
#
# grow and width are numbers on the wire and become CSS only here.
# Without them a fixed sidebar beside a filling centre -- the shape
# both migrated apps are built on -- could not be said at all.
grown <- component_to_html(component("column", grow = 1L,
                                     children = list(component("text",
                                                               value = "x"))))
expect_true(grepl("--g-grow:1", grown, fixed = TRUE))
expect_true(grepl("g-sized", grown, fixed = TRUE))

fixed <- component_to_html(component("panel", width = 280L,
                                     variant = "sidebar",
                                     children = list()))
expect_true(grepl("--g-shrink:0", fixed, fixed = TRUE))
expect_true(grepl("--g-basis:280px", fixed, fixed = TRUE))
expect_true(grepl("--g-width:280px", fixed, fixed = TRUE))
expect_true(grepl("g-sized", fixed, fixed = TRUE))

# a container with neither carries no sizing style at all, rather
# than a style attribute holding nothing
plainrow <- component_to_html(component("row",
                                        children = list(component("text",
                                                                  value = "x"))))
expect_false(grepl("--g-", plainrow, fixed = TRUE))
expect_false(grepl("g-sized", plainrow, fixed = TRUE))
expect_false(grepl('style=""', plainrow, fixed = TRUE))

# --- sizing never inherits ---
#
# Custom properties cascade. An element that set only the properties
# it needed picked the rest up from a sized ancestor: a fixed-width
# child inside a grown parent inherited --g-grow and grew, and a grown
# child inside a fixed parent inherited --g-width and did not. Every
# sized element states all four, so nothing is inherited.
fixed_in_grown <- component_to_html(
    component("row", grow = 1L, children = list(
            component("panel", width = 280L, children = list())
        )))
expect_true(grepl("--g-grow:1;--g-shrink:1;--g-basis:0;--g-width:auto",
                  fixed_in_grown, fixed = TRUE))
expect_true(grepl("--g-grow:0;--g-shrink:0;--g-basis:280px;--g-width:280px",
                  fixed_in_grown, fixed = TRUE))

grown_in_fixed <- component_to_html(
    component("panel", width = 280L, children = list(
            component("column", grow = 1L, children = list())
        )))
expect_true(grepl("--g-grow:0;--g-shrink:0;--g-basis:280px;--g-width:280px",
                  grown_in_fixed, fixed = TRUE))
expect_true(grepl("--g-grow:1;--g-shrink:1;--g-basis:0;--g-width:auto",
                  grown_in_fixed, fixed = TRUE))

# every sized element names all four, whichever field was set
for (h in c(fixed_in_grown, grown_in_fixed)) {
    n_sized <- length(gregexpr("g-sized", h)[[1]])
    for (v in c("--g-grow", "--g-shrink", "--g-basis", "--g-width")) {
        expect_equal(length(gregexpr(v, h, fixed = TRUE)[[1]]), n_sized)
    }
}

# grow and width are contradictory instructions, and the two lowerings
# resolve them differently -- the browser lets the later CSS rule win,
# Flutter lets Expanded win. Refused rather than silently divergent.
expect_error(component("row", grow = 1L, width = 280L,
                       children = list()),
             "not both")
expect_error(component("column", grow = 1L, width = 280L,
                       children = list()),
             "not both")
expect_error(component("panel", grow = 1L, width = 280L,
                       children = list()),
             "not both")
# grow = 0 is "does not grow", so it does not conflict with a width
expect_silent(component("row", grow = 0L, width = 280L, children = list()))

# gap and grow compose rather than one clobbering the other
both <- component_to_html(component("row", gap = 16L, grow = 2L,
                                    children = list(component("text",
                                                              value = "x"))))
expect_true(grepl("gap:16px", both, fixed = TRUE))
expect_true(grepl("--g-grow:2", both, fixed = TRUE))

# --- the workspace vocabulary: full page, stretched row, filled
# panel, scrolling column ---
#
# Together these say "editor" instead of "document": the page takes
# the viewport, side-by-side panels match heights, and a log inside
# one grows and scrolls instead of growing the page.
full <- component_to_html(component("page", width = "full",
                                    children = list()))
expect_true(grepl("g-page g-page-full", full, fixed = TRUE))
expect_false(grepl("g-page-full",
                   component_to_html(component("page", children = list())),
                   fixed = TRUE))
expect_error(component("page", width = "wide", children = list()),
             "content, full")

stretch <- component_to_html(component("row", align = "stretch",
                                       children = list()))
expect_true(grepl("align-items:stretch", stretch, fixed = TRUE))

filled <- component_to_html(component("panel", fill = TRUE,
                                      children = list()))
expect_true(grepl("g-fill", filled, fixed = TRUE))
expect_false(grepl("g-fill",
                   component_to_html(component("panel", children = list())),
                   fixed = TRUE))

scroller <- component_to_html(component("column", scroll = TRUE, grow = 1L,
                                        children = list()))
expect_true(grepl("g-scroll", scroller, fixed = TRUE))
expect_true(grepl("g-sized", scroller, fixed = TRUE))
expect_false(grepl("g-scroll",
                   component_to_html(component("column", children = list())),
                   fixed = TRUE))

# fill belongs to panel and scroll to column; the schema refuses the
# transplant rather than ignoring it
expect_error(component("row", scroll = TRUE, children = list()),
             "unknown field")
expect_error(component("column", fill = TRUE, children = list()),
             "unknown field")

# mono and small stay semantic: a class, never an inline style
expect_true(grepl("g-text g-mono",
                  component_to_html(component("text", value = "00:01:12",
                                              variant = "mono")),
                  fixed = TRUE))
expect_true(grepl("g-text g-small",
                  component_to_html(component("text", value = "fine",
                                              variant = "small")),
                  fixed = TRUE))
expect_true(grepl("g-output g-mono",
                  component_to_html(component("text_output", id = "tc",
                                              variant = "mono")),
                  fixed = TRUE))
expect_true(grepl("g-output g-small",
                  component_to_html(component("text_output", id = "fp",
                                              variant = "small")),
                  fixed = TRUE))

# --- v3.1: an image that is part of the UI ---
img <- component_to_html(component("image", src = "/static/logo.png",
                                   alt = "cornball.ai", width = 32L))
expect_true(grepl('<img class="g-image"', img, fixed = TRUE))
expect_true(grepl('src="/static/logo.png"', img, fixed = TRUE))
expect_true(grepl('alt="cornball.ai"', img, fixed = TRUE))
expect_true(grepl('width="32"', img, fixed = TRUE))

# --- v3.1: a link wraps children, or carries text, never both ---
wrapping <- component_to_html(component("link", href = "https://cornball.ai",
                                        children = list(component("image",
                                                                  src = "/l.png"))))
expect_true(grepl("<a href=", wrapping, fixed = TRUE))
expect_true(grepl("<img", wrapping, fixed = TRUE))

expect_error(component("link", href = "https://x"), "either value")
expect_error(component("link", href = "https://x", value = "text",
                       children = list(component("text", value = "y"))),
             "not both")

# --- v3.1: a collapsible section ---
open_one <- component_to_html(component("collapse", title = "Parameters",
                                        open = TRUE,
                                        children = list(component("text",
                                                                  value = "in"))))
expect_true(grepl("<details", open_one, fixed = TRUE))
expect_true(grepl('open="open"', open_one, fixed = TRUE))
expect_true(grepl("<summary", open_one, fixed = TRUE))
expect_true(grepl(">Parameters<", open_one, fixed = TRUE))

shut <- component_to_html(component("collapse", title = "API",
                                    children = list(component("text",
                                                              value = "in"))))
expect_false(grepl("open=", shut, fixed = TRUE))

# --- v3.1: a button's value rides on its event ---
#
# One handler serves a list of rows: the press says which row. Every
# row needing its own id and its own observer is impossible when the
# rows are built per render, which is what the history lists in both
# migrated apps do.
valued <- component_to_html(component("button", id = "history_view",
                                      label = "12:04", value = "entry_7"))
expect_true(grepl('data-g-value="entry_7"', valued, fixed = TRUE))
expect_true(grepl('data-g-message="event"', valued, fixed = TRUE))

# an ordinary button carries none: the press is the whole message
expect_false(grepl("data-g-value",
                   component_to_html(component("button", id = "go",
                                               label = "Run")),
                   fixed = TRUE))

# A component id says which handler hears the press, not which element
# it is -- and the two stop being the same thing exactly when `value`
# is in play, because that is what lets rows share a handler. Emitting
# it as a DOM id gave every row in a list the same one.
expect_false(grepl('id="history_view"', valued, fixed = TRUE))
expect_true(grepl('data-g-target="history_view"', valued, fixed = TRUE))

rows <- paste(vapply(c("a", "b", "c"), function(v) {
    component_to_html(component("button", id = "history_view", label = v,
                                value = v))
}, character(1L)), collapse = "")
expect_false(grepl(' id="', rows, fixed = TRUE))
expect_equal(length(gregexpr('data-g-target="history_view"', rows)[[1]]), 3L)
expect_equal(length(gregexpr("data-g-value=", rows)[[1]]), 3L)

# an ordinary button gets none either. Nothing makes a button id
# unique: a form with Save at the top and the bottom shares one
# without meaning anything by it, so two would collide.
plain_saves <- paste(rep(component_to_html(component("button", id = "save",
                                                     label = "Save")), 2L),
                     collapse = "")
expect_false(grepl(' id="save"', plain_saves, fixed = TRUE))
expect_equal(length(gregexpr('data-g-target="save"', plain_saves)[[1]]), 2L)

# an input keeps its id, because that id names one value in one store
expect_true(grepl('id="name"',
                  component_to_html(component("text_input", id = "name")),
                  fixed = TRUE))

# --- what each input reports is what INPUT_META declares ---
#
# The declaration used to be documentation nothing checked, which is
# how select_input came to say "string" for a control whose value is
# a list. Held against the seed, because that is the value the server
# starts with and the one a browser would have harvested.
seed_of <- glinty:::input_seed_value
r_type <- function(v) {
    if (is.null(v)) {
        "null"
    } else if (is.logical(v)) {
        "bool"
    } else if (is.numeric(v)) {
        if (length(v) == 1L) "number" else "numbers"
    } else if (length(v) == 1L) {
        "string"
    } else {
        "strings"
    }
}
for (nm in names(INPUT_META)) {
    meta <- INPUT_META[[nm]]
    if (is.null(meta$value_type)) {
        next
    }
    args <- list(nm, id = "probe")
    if (nm %in% c("select_input", "radio_buttons", "checkbox_group")) {
        args$choices <- c("a", "b")
    }
    if (nm %in% c("slider_input", "range_slider")) {
        args$min <- 0
        args$max <- 1
    }
    seed <- seed_of(do.call(component, args))
    # files and an unseeded field have no value to type-check
    if (!is.null(seed) && !identical(meta$value_type, "files")) {
        expect_equal(r_type(seed), meta$value_type)
    }
}

# the select declares both, and each one is what it actually seeds
expect_equal(INPUT_META$select_input$value_type, "string")
expect_equal(INPUT_META$select_input$value_type_multiple, "strings")

# a button is the other component whose message type depends on a
# field: valueless it counts presses, valued it carries the value.
# The declaration was NULL for both, and the loop above skips a NULL
# value_type -- so nothing checked the half that was added.
expect_null(INPUT_META$button$value_type)
expect_equal(INPUT_META$button$value_type_valued, "string")
expect_null(INPUT_META$download_button$value_type_valued)

s_ev <- glinty:::new_session("meta_ev")
glinty:::handle_event(s_ev, "counted")
expect_equal(r_type(glinty::isolate(s_ev$input$counted())), "number")
glinty:::handle_event(s_ev, "valued", "entry_7")
expect_equal(r_type(glinty::isolate(s_ev$input$valued())),
             INPUT_META$button$value_type_valued)
expect_equal(r_type(seed_of(component("select_input", id = "m",
                                      choices = c("a", "b"),
                                      selected = c("a", "b"),
                                      multiple = TRUE))),
             "strings")

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

# --- outputs are slots naming the kind they expect ---
for (nm in names(OUTPUT_KINDS)) {
    out <- component_to_html(do.call(component, list(nm, id = "slot")))
    expect_false(grepl("g-unsupported", out, fixed = TRUE))
    expect_true(grepl('data-g-output="slot"', out, fixed = TRUE))
    expect_true(grepl(paste0('data-g-kind="', OUTPUT_KINDS[[nm]], '"'), out,
                      fixed = TRUE))
}

# a responsive plot carries no fixed dimensions: the client measures
# its own box and reports back through the `measure` message
resp <- component_to_html(component("plot_output", id = "p"))
expect_true(grepl("aspect-ratio", resp, fixed = TRUE))
fixed_plot <- component_to_html(component("plot_output", id = "p",
                                          width = 400L, height = 300L))
expect_true(grepl('width="400"', fixed_plot, fixed = TRUE))
expect_false(grepl("aspect-ratio", fixed_plot, fixed = TRUE))

# a height-only plot still tracks its container's width -- the
# timeline-strip shape -- but its height is declared, so the aspect
# fallback stays off
half_plot <- component_to_html(component("plot_output", id = "p",
                                         height = 340L))
expect_true(grepl("width:100%", half_plot, fixed = TRUE))
expect_false(grepl("aspect-ratio", half_plot, fixed = TRUE))
expect_true(grepl('height="340"', half_plot, fixed = TRUE))

# width-only stays fully declared on that axis: no container tracking
wide_plot <- component_to_html(component("plot_output", id = "p",
                                         width = 400L))
expect_false(grepl("width:100%", wide_plot, fixed = TRUE))
expect_true(grepl('width="400"', wide_plot, fixed = TRUE))

# --- video_output: a real element, flags as attributes ---
#
# preload="metadata" always: duration and dimensions arrive, the
# frames wait for a play or a seek, which byte-range-requests exactly
# what it needs.
vid <- component_to_html(component("video_output", id = "v"))
expect_true(grepl("<video", vid, fixed = TRUE))
expect_true(grepl('data-g-kind="video"', vid, fixed = TRUE))
expect_true(grepl('controls="controls"', vid, fixed = TRUE))
expect_true(grepl('preload="metadata"', vid, fixed = TRUE))
expect_false(grepl("autoplay", vid, fixed = TRUE))
expect_false(grepl("muted", vid, fixed = TRUE))
expect_false(grepl("loop", vid, fixed = TRUE))

wall <- component_to_html(component("video_output", id = "w",
                                    controls = FALSE, autoplay = TRUE,
                                    muted = TRUE, loop = TRUE))
expect_false(grepl("controls", wall, fixed = TRUE))
expect_true(grepl('autoplay="autoplay"', wall, fixed = TRUE))
expect_true(grepl('muted="muted"', wall, fixed = TRUE))
expect_true(grepl('loop="loop"', wall, fixed = TRUE))

# --- tabset marks exactly one panel open ---
tabs <- component_to_html(component("tabset", id = "t", panels = list(
    list(title = "One", children = list(component("text", value = "a"))),
    list(title = "Two", children = list(component("text", value = "b")))
)))
expect_equal(lengths(regmatches(tabs, gregexpr("g-tab-active", tabs))), 1L)
expect_equal(lengths(regmatches(tabs, gregexpr("g-hidden", tabs))), 1L)
# both panels are present in the DOM, which is how their inputs keep
# their values while hidden -- a browser property Flutter shares and
# an immediate-mode renderer would not
expect_true(grepl(">a<", tabs, fixed = TRUE))
expect_true(grepl(">b<", tabs, fixed = TRUE))

# --- a checkbox group binds the box, never the members ---
#
# A member carrying data-g-target would send a scalar boolean where
# the server keeps a list, so the binding sits on the box and the
# members carry only their marker. Mirrors range_slider's rule.
grp <- component_to_html(component("checkbox_group", id = "tops",
                                   choices = c(A = "a", B = "b", C = "c"),
                                   selected = c("a", "c")))
expect_equal(lengths(regmatches(grp,
    gregexpr('data-g-target="tops"', grp, fixed = TRUE))), 1L)
expect_equal(lengths(regmatches(grp,
    gregexpr("data-g-group-member", grp, fixed = TRUE))), 3L)
expect_equal(lengths(regmatches(grp,
    gregexpr('checked="checked"', grp, fixed = TRUE))), 2L)
expect_false(grepl('type="checkbox"[^>]*data-g-target', grp))

# --- a searchable select lowers to a combobox, value on the box ---
#
# No <select> at all: a text input filters a pre-rendered option
# list, the binding and current value sit on the box so an adopted
# page recovers everything from the DOM, and the input shows the
# selected label rather than the value.
cmb <- component_to_html(component("select_input", id = "state",
                                   choices = c(Alabama = "AL",
                                               Alaska = "AK"),
                                   search = TRUE, selected = "AK"))
expect_false(grepl("<select", cmb, fixed = TRUE))
expect_true(grepl('class="g-combo"', cmb, fixed = TRUE))
expect_true(grepl('data-g-selected="AK"', cmb, fixed = TRUE))
expect_equal(lengths(regmatches(cmb,
    gregexpr('data-g-target="state"', cmb, fixed = TRUE))), 1L)
expect_equal(lengths(regmatches(cmb,
    gregexpr("g-combo-option", cmb, fixed = TRUE))), 2L)
expect_true(grepl('value="Alaska"', cmb, fixed = TRUE))
expect_true(grepl("No matches", cmb, fixed = TRUE))
# unselected defaults to the first choice, the plain select's rule
cmb2 <- component_to_html(component("select_input", id = "s",
                                    choices = c(A = "a", B = "b"),
                                    search = TRUE))
expect_true(grepl('data-g-selected="a"', cmb2, fixed = TRUE))
expect_true(grepl('value="A"', cmb2, fixed = TRUE))
# a plain select is untouched by the flag's existence
plain <- component_to_html(component("select_input", id = "s",
                                     choices = c(A = "a")))
expect_true(grepl("<select", plain, fixed = TRUE))
expect_false(grepl("g-combo", plain, fixed = TRUE))

# --- a data table lowers to an empty shell carrying its options ---
#
# The interactive build happens client-side when the value arrives,
# so the server emits only the slot plus the display options as data
# attributes -- the exact shell glinty.js builds, or hydration lies.
dtab <- component_to_html(component("data_table", id = "grid",
                                    page_length = 5L,
                                    length_menu = c(5, 30, 50),
                                    searchable = FALSE))
expect_true(grepl('class="g-table-output g-datatable"', dtab, fixed = TRUE))
expect_true(grepl('data-g-page-length="5"', dtab, fixed = TRUE))
expect_true(grepl('data-g-length-menu="5,30,50"', dtab, fixed = TRUE))
expect_true(grepl('data-g-searchable="0"', dtab, fixed = TRUE))
expect_true(grepl('data-g-sortable="1"', dtab, fixed = TRUE))
expect_true(grepl('data-g-output="grid"', dtab, fixed = TRUE))
# empty: no table markup until a value arrives
expect_false(grepl("<table", dtab, fixed = TRUE))
