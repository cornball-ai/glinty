# The one bug class the suites cannot see.
#
# A stylesheet conflict has no failing assertion: every rule is valid,
# the lowering is right, nothing errors, and the page is wrong. Two
# landed in one afternoon of looking at rendered pages, after fifteen
# review rounds had found neither.

css_rules <- glinty:::css_rules
families <- glinty:::css_variant_families
props <- glinty:::css_variant_properties
styled <- glinty:::css_variant_classes_styled

# --- the reader ---
r <- css_rules(".a { color: red; padding: 1px }")
expect_equal(length(r), 1L)
expect_equal(r[[1]]$selectors, ".a")
expect_equal(r[[1]]$properties, c("color", "padding"))

# comments are not declarations
expect_equal(css_rules("/* color: red */ .a { padding: 1px }")[[1]]$properties,
             "padding")

# a comma list is several selectors sharing one body
r <- css_rules(".a, .b { color: red }")
expect_equal(r[[1]]$selectors, c(".a", ".b"))

# a media query holds rules, not declarations, and its contents override
# the same properties -- so they have to count
r <- css_rules("@media (max-width: 10px) { .a { color: red } }")
expect_equal(length(r), 1L)
expect_equal(r[[1]]$selectors, ".a")
expect_equal(r[[1]]$properties, "color")

# --- the families come from the lowering, not from a list ---
#
# They used to be stated, and the statement was wrong. It claimed
# `.g-text-muted` where html_text() emits `g-text g-muted`, gave
# divider a `.g-divider-line` that no markup carries, and had no entry
# for text_output, which lowers to `.g-output`. The tests checked the
# table against COMPONENT_SCHEMA -- which is where the variant *values*
# come from -- so a table built out of those values agreed with itself
# and the markup was never consulted.
components <- glinty:::css_variant_components()
builders <- glinty:::CSS_VARIANT_BUILDERS
outer_classes <- glinty:::html_outer_classes
component_to_html <- glinty:::component_to_html

# every component the schema gives a variant has a builder here, so a
# variant added to the vocabulary cannot go unguarded
schema_with_variants <- Filter(function(n) {
    !is.null(glinty:::COMPONENT_SCHEMA[[n]]$variant)
}, names(glinty:::COMPONENT_SCHEMA))
expect_equal(sort(names(builders)), sort(schema_with_variants))

# and every class in the derivation is one the lowering really emits
for (entry in components) {
    for (value in entry$values) {
        cls <- outer_classes(component_to_html(
                builders[[entry$component]](value)))
        expect_true(all(entry$shared %in% cls),
                    info = paste(entry$component, value, "carries the base"))
        expect_equal(setdiff(cls, c(entry$shared, entry$telling)),
                     character(0),
                     info = paste(entry$component, value,
                                  "emits no class the derivation missed"))
    }
}

fam <- families()

# the specific claims the stated table got wrong
expect_true(all(c("g-muted", "g-strong") %in% fam[["g-text"]]))
expect_false("g-text-muted" %in% fam[["g-text"]])
expect_false("g-divider-line" %in% fam[["g-divider"]])
# text_output is its own family: .g-output, not .g-text
expect_true("g-output" %in% names(fam))
expect_true(all(c("g-muted", "g-strong") %in% fam[["g-output"]]))
expect_false("g-output" %in% fam[["g-text"]])
# download_button shares g-btn and adds g-download, and a rule on
# either one cancels the variants, so both are bases
expect_true(all(c("g-btn", "g-download") %in% names(fam)))
expect_equal(fam[["g-download"]], fam[["g-btn"]])
expect_true(all(paste0("g-btn-",
                       glinty:::COMPONENT_SCHEMA$button$variant$values) %in%
                fam[["g-btn"]]))

# --- the stated names match the stylesheet ---
# Not every variant needs a rule: default and normal are deliberately
# the unstyled case. But a name spelled one way here and another way in
# the stylesheet would leave a guard that checks nothing, so at least
# some of each family must be found.
found <- styled()
expect_true(length(found) > 0L)
for (base in names(fam)) {
    # By membership, not by prefix: .g-muted is one of .g-text's
    # variants and shares none of its name.
    expect_true(any(fam[[base]] %in% found),
                info = paste(base, "has at least one styled variant"))
}
# and every styled name is one the families claim
expect_equal(setdiff(found, unlist(fam, use.names = FALSE)), character(0))

# --- what a base rule would cancel ---
p <- props()
expect_true("background" %in% p[["g-btn"]])
expect_true("color" %in% p[["g-btn"]])

# --- the guard itself ---
tmp <- tempfile(fileext = ".css")

# The bug as it actually shipped in an app: the gradient on the base
# class, which loads after glinty's and wins at equal specificity, so
# every ghost button came out as a purple pill.
writeLines(".g-btn { background: linear-gradient(red, blue); color: #fff }",
           tmp)
found <- glinty::css_variant_conflicts(tmp)
expect_equal(length(found), 1L)
expect_true(grepl("background", found[1]))
expect_true(grepl("color", found[1]))
# the message names the classes that exist, not a pattern built from
# the base name: `.g-text-*` would be an invention for a family whose
# members are `.g-muted` and `.g-strong`
expect_true(grepl(".g-btn-ghost", found[1], fixed = TRUE))
expect_false(grepl("-*", found[1], fixed = TRUE))

writeLines(".g-text { color: red }", tmp)
found <- glinty::css_variant_conflicts(tmp)
expect_equal(length(found), 1L)
expect_true(grepl(".g-muted", found[1], fixed = TRUE))
expect_false(grepl(".g-text-*", found[1], fixed = TRUE))

writeLines(".g-download { background: red }", tmp)
found <- glinty::css_variant_conflicts(tmp)
expect_equal(length(found), 1L)
expect_true(grepl(".g-btn-primary", found[1], fixed = TRUE))
expect_false(grepl(".g-download-", found[1], fixed = TRUE))

writeLines(".g-btn { background: linear-gradient(red, blue); color: #fff }",
           tmp)

# The fix: the gradient belongs to the variant it describes.
writeLines(c(".g-btn { font-size: 0.95rem; border-radius: 8px; cursor: pointer }",
             ".g-btn-primary { background: linear-gradient(red, blue) }"), tmp)
expect_equal(glinty::css_variant_conflicts(tmp), character(0))

# An app narrowing its reach is doing the right thing, and is not a
# finding: both of these beat glinty's variants on specificity, which is
# the point of writing them that way.
writeLines(c("#header .g-btn { background: red }",
             ".g-btn.g-btn-ghost { background: none }"), tmp)
expect_equal(glinty::css_variant_conflicts(tmp), character(0))

# Shared geometry on the base class is what the base class is for.
writeLines(".g-btn { font-family: inherit; cursor: pointer }", tmp)
expect_equal(glinty::css_variant_conflicts(tmp), character(0))

# Every family is guarded, not just buttons.
writeLines(".g-panel { padding: 2rem }", tmp)
expect_true(grepl("g-panel", glinty::css_variant_conflicts(tmp)[1]))
writeLines(".g-text { font-weight: 700 }", tmp)
expect_true(grepl("g-text", glinty::css_variant_conflicts(tmp)[1]))

# A media query is not a hiding place: the rule inside it overrides the
# same property as one outside.
writeLines("@media (max-width: 700px) { .g-btn { background: red } }", tmp)
expect_equal(length(glinty::css_variant_conflicts(tmp)), 1L)

unlink(tmp)

# --- glinty's own stylesheet passes its own guard ---
# It is allowed to style its base classes, being the one that defines
# the variants and loading first, but a base rule setting something a
# variant also sets is still a smell worth knowing about.
own <- system.file("www", "glinty.css", package = "glinty")
expect_true(nzchar(own))

# --- the CSS subset this reader supports, as fixtures ---
#
# Declarations are found by splitting on ; and :, and both hide inside
# values that are none of this reader's business. glinty's own
# stylesheet is full of the worst case: every icon is a mask-image data
# URI, semicolon and all. Split naively they produced declarations that
# were not ones -- `utf8,<svg/>")` read as a property name.
props_of <- function(css) css_rules(css)[[1]]$properties

expect_equal(props_of('.a { background: url("data:image/svg+xml;utf8,<svg/>"); color: red }'),
             c("background", "color"))
expect_equal(props_of('.b::after { content: ";"; padding: 1px }'),
             c("content", "padding"))
expect_equal(props_of('.c { background: url(data:image/png;base64,AAA=) no-repeat; margin: 0 }'),
             c("background", "margin"))
expect_equal(props_of('.d { font-family: "a;b", serif }'), "font-family")
expect_equal(props_of(".e { content: ':' ; color: red }"), c("content", "color"))
# a colon in a value, which is the ordinary case for a data URI
expect_equal(props_of('.f { background: url(http://x/y.png) }'), "background")

# and glinty's own stylesheet, which is the real fixture: every
# property it reads out should look like a CSS property name, not like
# the inside of a data URI
own <- readLines(system.file("www", "glinty.css", package = "glinty"),
                 warn = FALSE)
all_props <- unique(unlist(lapply(css_rules(own), function(r) r$properties)))
expect_true(length(all_props) > 20L)
expect_equal(all_props[!grepl("^-?-?[a-z][a-z0-9-]*$", all_props)], character(0))

# --- the documented scope: bare base classes only ---
#
# Narrow on purpose. A compound selector is an app beating a variant
# deliberately, and flagging it would make the guard cry wolf. The cost
# is that a base-class *hover* rule really does overrule a variant's
# hover and this will not say so, which is what the headless
# computed-style check is for.
tmp2 <- tempfile(fileext = ".css")
writeLines(".g-btn:hover { background: red }", tmp2)
expect_equal(glinty::css_variant_conflicts(tmp2), character(0),
             info = "a pseudo-class is out of scope, and documented as such")
writeLines(".g-btn, .other { background: red }", tmp2)
expect_equal(length(glinty::css_variant_conflicts(tmp2)), 1L,
             info = "but a bare base class in a comma list is still bare")
unlink(tmp2)

# A multi-line comment is still a comment. `.` does not match a newline
# in perl mode, so without (?s) these were not stripped at all -- and
# glinty.css is full of them. The whole comment came back glued to the
# property after it, which lost that property rather than merely adding
# a phantom beside it: a false negative, not just noise. Found by
# asserting that every property read out of glinty.css looks like a
# property name.
expect_equal(props_of("/* one\n   two\n   three */ .a { color: red }"), "color")
expect_equal(props_of(".a { /* mid\n rule */ color: red; padding: 0 }"),
             c("color", "padding"))
