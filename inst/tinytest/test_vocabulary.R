# The declaration tables clients carry, held equal to the R schema.
#
# A client's support list states what that client implements, and its
# variant list gates its own style maps -- neither can be generated
# from the schema without lying (claiming support with no builder) or
# breaking (accepting a variant with no style). So the relation is
# verified restatement: the schema is read here, the client's literal
# tables are read out of its source, and any difference fails loudly.
# Before this test existed, glinty.js had implemented shortcut and
# table_output while declaring neither in hello, and nothing noticed.

schema <- glinty:::COMPONENT_SCHEMA
vocabulary <- glinty:::vocabulary

schema_variants <- Filter(Negate(is.null),
                          lapply(schema, function(s) s$variant$values))

# --- schema invariants the fallback rule leans on ---
# An unknown variant falls back to the first listed value, in every
# client. That is only coherent while the first listed value IS the
# schema default, and while no list repeats itself.
for (nm in names(schema_variants)) {
    values <- schema_variants[[nm]]
    expect_true(length(values) >= 2L, info = paste(nm, "has choices"))
    expect_equal(anyDuplicated(values), 0L, info = nm)
    expect_equal(schema[[nm]]$variant$default, values[[1L]],
                 info = paste(nm, ": fallback (first listed) is the default"))
}

# --- vocabulary(): the block that rides components.json ---
v <- vocabulary()
expect_equal(as.character(v$components), names(schema))
expect_equal(names(v$variants), names(schema_variants))
for (nm in names(schema_variants)) {
    expect_equal(as.character(v$variants[[nm]]), schema_variants[[nm]])
}

# --- reading the browser's tables out of its source ---
js_path <- system.file("www", "glinty.js", package = "glinty")
expect_true(nzchar(js_path))
js <- paste(readLines(js_path, warn = FALSE), collapse = "\n")

# The literal between an opening marker and its closing bracket. The
# markers are exact source text, so a refactor that renames or removes
# a table fails here rather than silently testing nothing.
js_block <- function(open, close) {
    start <- regexpr(open, js, fixed = TRUE)
    expect_true(start > 0L, info = paste("glinty.js still declares", open))
    rest <- substring(js, start + attr(start, "match.length"))
    end <- regexpr(close, rest, fixed = TRUE)
    expect_true(end > 0L)
    substring(rest, 1L, end - 1L)
}
quoted <- function(txt) {
    gsub('"', "", regmatches(txt, gregexpr('"[a-z_]+"', txt))[[1L]])
}

# The browser renders the full set, so its support list is the schema
# component list exactly -- no more (a claim with no schema behind it)
# and no less (an implementation hello never mentions).
sup <- quoted(js_block("var SUPPORTED_COMPONENTS = [", "]"))
expect_equal(anyDuplicated(sup), 0L)
expect_equal(sort(sup), sort(names(schema)))

# KNOWN_VARIANTS equals the schema map exactly: same components, and
# per component the same values in the same order, because position
# one is the fallback.
kv_txt <- js_block("var KNOWN_VARIANTS = {", "};")
entries <- regmatches(kv_txt,
                      gregexpr("([a-z_]+):\\s*\\[[^]]*\\]", kv_txt))[[1L]]
kv <- lapply(entries, quoted)
names(kv) <- sub(":.*$", "", entries)
expect_equal(sort(names(kv)), sort(names(schema_variants)))
for (nm in names(schema_variants)) {
    expect_equal(kv[[nm]], schema_variants[[nm]], info = nm)
}

# The Flutter client's tables are held to the same schema by its own
# suite (fixtures_test.dart reads the vocabulary block out of
# inst/fixtures/components.json), so each client is checked where its
# toolchain lives.
