# The cascade's answer, rather than the source.
#
# Most of this needs no browser: the rewriting, the probe markup and
# the differential are ordinary functions and are tested as such. The
# measurements themselves need a real one, and those tests say so out
# loud when there is none rather than passing quietly -- CI installs a
# browser precisely so the claim is checked somewhere.

css_force_states <- glinty:::css_force_states
computed_longhands <- glinty:::computed_longhands
probe_element <- glinty:::probe_element
computed_findings <- glinty:::computed_findings
computed_probe_families <- glinty:::computed_probe_families
computed_probe_html <- glinty:::computed_probe_html
find_chrome <- glinty:::find_chrome

# --- states become classes of the same specificity ---
#
# A pseudo-class and a class weigh the same, so the swap changes which
# elements match and nothing about which rule wins.
expect_equal(css_force_states(".g-btn:hover { filter: none }"),
             ".g-btn.g-force-hover { filter: none }")
expect_equal(css_force_states(".a:focus, .b:active { color: red }"),
             ".a.g-force-focus, .b.g-force-active { color: red }")
# one class token replaces one pseudo-class, not two
expect_equal(lengths(regmatches(css_force_states(".g-btn:hover"),
                                gregexpr("\\.", css_force_states(".g-btn:hover")))),
             2L)

# pseudo-elements are elements, not states, and are left alone
expect_equal(css_force_states(".g-divider-labelled::after { content: '' }"),
             ".g-divider-labelled::after { content: '' }")
# a pseudo-class this does not force is left alone, which is a gap in
# coverage rather than a wrong answer
expect_equal(css_force_states(".a:focus-visible { color: red }"),
             ".a:focus-visible { color: red }")
expect_equal(css_force_states(":root { --g-primary: red }"),
             ":root { --g-primary: red }")

# --- selector preludes only ---
#
# A declaration's value is none of this function's business, and a
# stylesheet is full of values a plain gsub would rewrite. Both of
# these are legal CSS that used to come out mangled.
expect_equal(css_force_states('.a::after { content: ":hover" }'),
             '.a::after { content: ":hover" }')
expect_equal(css_force_states(".a { background: url(data:image/svg+xml;utf8,<svg id=':hover'/>) }"),
             ".a { background: url(data:image/svg+xml;utf8,<svg id=':hover'/>) }")
# the selector is still rewritten when a value nearby mentions a state
expect_equal(css_force_states('.a:hover { content: ":hover" }'),
             '.a.g-force-hover { content: ":hover" }')

# a media query holds rules, so the selectors inside it are preludes
# too -- and the declarations inside those are not
expect_equal(
    css_force_states("@media (max-width: 9px) { .a:hover { content: ':hover' } }"),
    "@media (max-width: 9px) { .a.g-force-hover { content: ':hover' } }")
# but a block that holds declarations does not get its values rewritten
expect_equal(css_force_states("@font-face { src: url(':hover.woff') }"),
             "@font-face { src: url(':hover.woff') }")

# --- escapes are counted, not glanced at ---
#
# An escaped colon is part of a class name, and a quote after an even
# number of backslashes really does close its string. Testing the one
# preceding character gets both wrong, and the second one is the worse
# failure: the scanner stays "inside" a string that ended, so every
# rewrite after it is suppressed and the guard comes back clean.
css_escaped <- glinty:::css_escaped
chars <- strsplit("a\\\\b\\c", "", fixed = TRUE)[[1]]
expect_false(css_escaped(chars, 1L))
expect_false(css_escaped(chars, 4L))
expect_true(css_escaped(chars, 6L))

# a colon that is part of the class name is left alone
expect_equal(css_force_states(".icon\\:hover { color: red }"),
             ".icon\\:hover { color: red }")
# a string ending in an escaped backslash closes, and what follows is
# still a prelude
expect_equal(
    css_force_states('.a::before { content: "\\\\" }\n.b:hover { color: red }'),
    '.a::before { content: "\\\\" }\n.b.g-force-hover { color: red }')
# an escaped quote does not close it, and the next real one does
expect_equal(
    css_force_states('.a::before { content: "\\"" }\n.b:hover { color: red }'),
    '.a::before { content: "\\"" }\n.b.g-force-hover { color: red }')

# --- a comment is text, whatever it looks like ---
#
# An unmatched brace inside one opens a block this scanner never
# closes, and every selector after it reads as a declaration and goes
# unforced -- so the guard finds nothing and says so. Which is the
# shape of every bug in this file: the clean answer, for the wrong
# reason.
expect_equal(
    css_force_states("/* .g-btn:hover { */\n.g-btn:hover { filter: none }"),
    "/* .g-btn:hover { */\n.g-btn.g-force-hover { filter: none }")
# an unmatched closing brace is just as bad the other way
expect_equal(css_force_states("/* } */ .a:hover { color: red }"),
             "/* } */ .a.g-force-hover { color: red }")
# a quote inside a comment does not open a string
expect_equal(css_force_states("/* don't { */ .a:focus { color: red }"),
             "/* don't { */ .a.g-force-focus { color: red }")
# a comment inside a declaration block does not end it
expect_equal(css_force_states(".a { /* :hover } */ color: red }\n.b:active { top: 0 }"),
             ".a { /* :hover } */ color: red }\n.b.g-force-active { top: 0 }")
# and a comment that never closes ends the scan rather than looping
expect_true(grepl("unterminated",
                  css_force_states(".a:hover { color: red } /* unterminated"),
                  fixed = TRUE))

# glinty's own stylesheet survives the round trip: every property it
# reads out afterwards still looks like a property name, which is what
# caught a rewrite leaking into values in the first place
own <- readLines(system.file("www", "glinty.css", package = "glinty"),
                 warn = FALSE)
forced <- css_force_states(paste(own, collapse = "\n"))
props <- unique(unlist(lapply(glinty:::css_rules(forced),
                              function(r) r$properties)))
expect_equal(props[!grepl("^-?-?[a-z][a-z0-9-]*$", props)], character(0))
# and the rewrite really happened
expect_true(grepl("g-force-hover", forced, fixed = TRUE))

# --- shorthands are read back as the longhands they set ---
expect_true(all(c("background-color", "background-image") %in%
                computed_longhands("background")))
expect_equal(computed_longhands("color"), "color")
expect_equal(computed_longhands(c("color", "color")), "color")
# a custom property resolves to whatever it was set to and says
# nothing about what the element looks like
expect_equal(computed_longhands(c("--g-primary", "color")), "color")

# --- probe markup is tagged, and the tagging is checked ---
html <- probe_element('<button class="g-btn g-btn-ghost">x</button>',
                      "g-btn|ghost|hover", force = "hover")
expect_true(grepl('data-probe="g-btn|ghost|hover"', html, fixed = TRUE))
expect_true(grepl('class="g-force-hover g-btn g-btn-ghost"', html,
                  fixed = TRUE))
# the force class goes on the element itself: on a wrapper it would
# not match .g-btn.g-force-hover at all
expect_true(grepl("^<button ", html))

plain <- probe_element('<hr class="g-divider g-divider-line">', "d|line|")
expect_true(grepl('data-probe="d|line|"', plain, fixed = TRUE))
expect_false(grepl("g-force", plain, fixed = TRUE))

# a lowering that stopped emitting a class attribute would leave a
# probe that measures nothing, so it is an error rather than a shrug
expect_error(probe_element("<button>x</button>", "id", force = "hover"),
             pattern = "no class attribute")
expect_error(probe_element("text with no tag", "id"), pattern = "tag")

# --- the differential ---
#
# A finding is a distinction glinty makes and the app removes. Nothing
# else is: an app introducing a distinction glinty did not make is an
# app styling its variants, which is what variants are for.
before <- list("g-btn||color" = list(distinct = 3L, values = list("a", "b", "c")),
               "g-btn||filter" = list(distinct = 1L, values = list("none")),
               "g-btn|hover|filter" = list(distinct = 2L,
                                           values = list("x", "y")))
after <- list("g-btn||color" = list(distinct = 1L, values = list("z")),
              "g-btn||filter" = list(distinct = 1L, values = list("none")),
              "g-btn|hover|filter" = list(distinct = 2L,
                                          values = list("x", "y")))
found <- computed_findings(before, after)
expect_equal(length(found), 1L)
expect_true(grepl("color", found[1], fixed = TRUE))
expect_true(grepl("share one", found[1], fixed = TRUE))

# collapsing a hover distinction is a finding, and says which state
after$"g-btn|hover|filter" <- list(distinct = 1L, values = list("none"))
found <- computed_findings(before, after)
expect_equal(length(found), 2L)
expect_true(any(grepl("on :hover", found, fixed = TRUE)))

# a property glinty itself does not distinguish cannot be cancelled
expect_equal(computed_findings(
        list(k = list(distinct = 1L, values = list("a"))),
        list(k = list(distinct = 1L, values = list("b")))), character(0))

# --- a short measurement is an error, not a clean bill ---
#
# Both runs measure the same probe plan, so the key sets must match.
# One of them coming back short means a page failed to render or the
# script stopped early, and every conclusion drawn from it would be
# "no findings" -- the answer that looks like success.
expect_error(computed_findings(before, list()),
             pattern = "do not cover the same probes")
expect_error(computed_findings(before, c(after, list(surprise = after[[1]]))),
             pattern = "unexpected")
expect_error(computed_findings(list(), after), pattern = "unexpected")

# the label names the classes an app would write, not the component
labelled <- computed_findings(
    list("text||color" = list(distinct = 2L, values = list("a", "b"))),
    list("text||color" = list(distinct = 1L, values = list("a"))),
    labels = c(text = ".g-text"))
expect_true(grepl(".g-text", labelled[1], fixed = TRUE))

# --- the probe covers every component that has variants ---
#
# One entry per component, not per base class: button and
# download_button both lower to .g-btn, and their probes must not
# collide.
props <- lapply(glinty:::css_variant_properties(), computed_longhands)
families <- computed_probe_families(props)
components <- vapply(families, function(f) f$component, character(1))
expect_true(all(names(glinty:::CSS_VARIANT_BUILDERS) %in% components))
expect_equal(anyDuplicated(components), 0L)
# text_output is probed, and under its own classes
outputs <- Filter(function(f) identical(f$component, "text_output"), families)
expect_equal(length(outputs), 1L)
expect_equal(outputs[[1]]$classes, "g-output")

for (family in families) {
    expect_true(length(family$variants) > 1L)
    # the markup comes from the real lowering, so it cannot drift from
    # what an app renders
    rendered <- glinty:::component_to_html(family$make(family$variants[1]))
    expect_true(all(family$classes %in% glinty:::html_outer_classes(rendered)),
                info = paste(family$component, "renders its base classes"))
}

# --- the page carries both stylesheets, in load order ---
page <- computed_probe_html("/* APP */", "/* GLINTY */", families)
expect_true(grepl("GLINTY", page, fixed = TRUE))
expect_true(grepl("APP", page, fixed = TRUE))
# the app's sheet loads second, which is the whole reason its rules win
expect_true(regexpr("GLINTY", page, fixed = TRUE) <
            regexpr("APP", page, fixed = TRUE))
# the plan is declared once, not once per line of the script
expect_equal(length(gregexpr("const plan =", page, fixed = TRUE)[[1]]), 1L)
# the baseline page is the same page without the app's stylesheet
baseline <- computed_probe_html(NULL, "/* GLINTY */", families)
expect_false(grepl("APP", baseline, fixed = TRUE))
expect_true(grepl("GLINTY", baseline, fixed = TRUE))

# --- and now the browser ---
chrome <- find_chrome()
if (is.null(chrome)) {
    # A broken find_chrome() would take this branch and report green,
    # which is the failure mode this file exists to refuse. Nothing
    # here can tell a machine without a browser from a finder that
    # stopped working -- but CI can, and sets GLINTY_REQUIRE_BROWSER.
    if (nzchar(Sys.getenv("GLINTY_REQUIRE_BROWSER", ""))) {
        expect_true(FALSE,
                    info = paste("GLINTY_REQUIRE_BROWSER is set and no",
                                 "browser was found: either the runner",
                                 "lost Chrome or find_chrome() is broken"))
    }
    # Not a skip that reports green: the function must refuse, and say
    # what to install.
    message("no browser found: the computed-style checks did not run")
    tmp <- tempfile(fileext = ".css")
    writeLines(".g-btn { color: red }", tmp)
    expect_error(glinty::css_computed_conflicts(tmp),
                 pattern = "no browser found")
    unlink(tmp)
} else {
    tmp <- tempfile(fileext = ".css")

    # The bug as it shipped in earshot: a gradient on the base class.
    # `background` is a shorthand and `background-color` is what gets
    # read back, so this is also the shorthand-against-longhand case
    # that reading selectors would have to model.
    writeLines(".g-btn { background: linear-gradient(red, blue); color: #fff }",
               tmp)
    found <- glinty::css_computed_conflicts(tmp)
    expect_true(length(found) > 0L)
    expect_true(any(grepl("background-color", found, fixed = TRUE)))

    # The case css_variant_conflicts() documents itself as unable to
    # see. This is the whole reason the file exists.
    writeLines(".g-btn:hover { filter: none }", tmp)
    found <- glinty::css_computed_conflicts(tmp)
    expect_true(length(found) > 0L)
    expect_true(all(grepl("on :hover", found, fixed = TRUE)))
    expect_true(any(grepl("filter", found, fixed = TRUE)))
    # and the source-level guard agrees it cannot see it
    expect_equal(glinty::css_variant_conflicts(tmp), character(0))

    # !important on the base class, which no source reader models
    writeLines(".g-btn { color: #333 !important }", tmp)
    expect_true(length(glinty::css_computed_conflicts(tmp)) > 0L)

    # The families used to be a stated table that claimed
    # `.g-text-muted`. html_text() emits `g-text g-muted`, so `color`
    # was never in the property set and this came back clean.
    writeLines(".g-text { color: red !important }", tmp)
    found <- glinty::css_computed_conflicts(tmp)
    expect_true(length(found) > 0L)
    expect_true(all(grepl("text variants", found, fixed = TRUE)))
    expect_true(any(grepl("color", found, fixed = TRUE)))

    # text_output has its own base class, and had no entry at all
    writeLines(".g-output { color: red; font-weight: 700 }", tmp)
    found <- glinty::css_computed_conflicts(tmp)
    expect_true(length(found) > 0L)
    expect_true(all(grepl("text_output variants", found, fixed = TRUE)))

    # Shared geometry is what a base class is for.
    writeLines(paste(".g-btn { font-family: inherit; cursor: pointer;",
                     "border-radius: 8px }"), tmp)
    expect_equal(glinty::css_computed_conflicts(tmp), character(0))

    # An app beating a variant on specificity is doing it on purpose.
    writeLines(c("#header .g-btn { background: red }",
                 ".g-btn.g-btn-ghost { background: none }"), tmp)
    expect_equal(glinty::css_computed_conflicts(tmp), character(0))

    # An empty stylesheet must be identical to the baseline: if this
    # ever fails, the two pages differ by something other than the app
    # CSS and every other result here is suspect.
    writeLines("/* nothing */", tmp)
    expect_equal(glinty::css_computed_conflicts(tmp), character(0))

    unlink(tmp)
}
