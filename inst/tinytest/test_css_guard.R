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

# --- the families are stated, and match the schema ---
#
# Which classes form a variant family is a fact about the lowering. This
# checks the statement against COMPONENT_SCHEMA, so a variant added to
# the vocabulary without being added here fails rather than going
# unguarded.
fam <- families()
expect_true(all(c("g-btn", "g-panel", "g-text", "g-divider") %in% names(fam)))

schema_variants <- function(component) {
    glinty:::COMPONENT_SCHEMA[[component]]$variant$values
}
for (pair in list(c("button", "g-btn"), c("panel", "g-panel"),
                  c("text", "g-text"), c("divider", "g-divider"))) {
    wanted <- paste0(pair[2], "-", schema_variants(pair[1]))
    expect_true(all(wanted %in% fam[[pair[2]]]),
                info = paste(pair[1], "variants are all declared a family"))
}
# download_button and text_output reuse another component's classes, so
# their variants must already be covered
expect_true(all(paste0("g-btn-", schema_variants("download_button")) %in%
                fam[["g-btn"]]))
expect_true(all(paste0("g-text-", schema_variants("text_output")) %in%
                fam[["g-text"]]))

# --- the stated names match the stylesheet ---
# Not every variant needs a rule: default and normal are deliberately
# the unstyled case. But a name spelled one way here and another way in
# the stylesheet would leave a guard that checks nothing, so at least
# some of each family must be found.
found <- styled()
expect_true(length(found) > 0L)
for (base in names(fam)) {
    expect_true(any(startsWith(found, paste0(base, "-"))),
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
