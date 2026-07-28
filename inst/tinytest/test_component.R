component <- glinty:::component
is_component <- glinty:::is_component
check_children <- glinty:::check_children
component_fixtures <- glinty:::component_fixtures
fixture_json <- glinty:::fixture_json
fixture_json_path <- glinty:::fixture_json_path
COMPONENT_SCHEMA <- glinty:::COMPONENT_SCHEMA
unclass_recursive <- glinty:::unclass_recursive

# --- construction ---
tx <- component("text", value = "hello")
expect_true(is_component(tx))
expect_equal(tx$component, "text")
expect_equal(tx$value, "hello")

# --- required fields ---
expect_error(component("text"), "requires field 'value'")
expect_error(component("link", value = "x"), "requires field 'href'")
expect_error(component("heading"), "requires field 'value'")

# An explicit NULL is an absent field, not a present one.
# names(list(value = NULL)) is "value", so a name-only check accepts it
# and the NULL-drop then deletes it, yielding a component missing a
# required field. Catch it as absent instead.
expect_error(component("text", value = NULL), "requires field 'value'")
expect_error(component("link", value = "x", href = NULL),
             "requires field 'href'")
expect_error(component("raw_html", html = NULL), "requires field 'html'")

# --- unknown fields are rejected, not silently carried ---
expect_error(component("text", value = "x", colour = "red"), "unknown field")
expect_error(component("text", value = "x", colour = "red"), "Allowed:")
expect_error(component("nonexistent", value = "x"), "unknown component type")

# --- types are enforced, not just names ---
expect_error(component("text", value = list(1, 2)), "a single string")
expect_error(component("text", value = c("a", "b")), "a single string")
expect_error(component("text", value = NA), "a single string")

expect_error(component("heading", value = "x", level = "two"),
             "a single number")
expect_error(component("heading", value = "x", level = 1.5),
             "a whole number")
expect_error(component("heading", value = "x", level = 99), "must be <= 4")
expect_error(component("heading", value = "x", level = 0), "must be >= 1")

expect_error(component("link", value = "a", href = "b", external = "yes"),
             "TRUE or FALSE")
expect_error(component("link", value = "a", href = "b", external = NA),
             "TRUE or FALSE")

expect_error(component("text", value = "x", variant = "sparkly"),
             "must be one of")
expect_error(component("text", value = "x", variant = "sparkly"), "normal")
expect_error(component("row", children = "oops"),
             "must be a list of components")
expect_error(component("spacer", size = -1), "must be >= 0")

# numbers coerce to their declared type
expect_true(is.integer(component("heading", value = "x", level = 3)$level))
# a numeric string is a valid string
expect_equal(component("text", value = 42)$value, "42")

# --- optional defaults are filled ---
expect_equal(component("text", value = "x")$variant, "normal")
expect_equal(component("heading", value = "x")$level, 2L)
expect_equal(component("icon", name = "play")$size, 16L)
expect_equal(component("spacer")$size, 1L)
expect_false(component("link", value = "a", href = "b")$external)
expect_equal(component("heading", value = "x", level = 4L)$level, 4L)

# --- an absent optional with no default is absent, not null ---
plain <- component("text", value = "x")
expect_false("id" %in% names(plain))
expect_true("variant" %in% names(plain))
expect_false("gap" %in% names(component("row", children = list())))

# --- children ---
expect_error(component("row", children = list("a bare string")),
             "not a component")
expect_error(component("row", children = list("a bare string")),
             "Wrap plain strings in text")

# The reported index is the caller's, not the post-filter one. A NULL
# earlier in the list must not renumber what follows.
expect_error(component("row", children = list(NULL, 42)), "child 2")
expect_error(component("column",
                       children = list(component("text", value = "a"), NULL,
                                       "bad")),
             "child 3")
expect_error(component("row", children = list(NULL, NULL, 42)), "child 3")

# NULLs drop, so conditional children compose
kids <- component("row", children = list(component("text", value = "a"), NULL,
                                         component("text", value = "b")))
expect_equal(length(kids$children), 2L)
expect_null(names(kids$children))

# validation runs through component(), so a builder cannot skip it
expect_error(component("page", children = list(1)), "not a component")

# --- the wire form is plain JSON with no R classes ---
tree <- component("column", children = list(
    component("heading", value = "Title", level = 1L),
    component("text", value = "body")
))
wire <- unclass_recursive(tree)
expect_null(attr(wire, "class"))
expect_equal(wire$component, "column")
expect_equal(wire$children[[1]]$component, "heading")
expect_equal(wire$children[[2]]$value, "body")

json <- as.character(jsonlite::toJSON(wire, auto_unbox = TRUE))
expect_true(grepl('"component":"column"', json, fixed = TRUE))
one <- unclass_recursive(component("row",
                                   children = list(component("text",
                                                             value = "solo"))))
expect_true(grepl('"children":[{',
                  as.character(jsonlite::toJSON(one, auto_unbox = TRUE)),
                  fixed = TRUE))

# --- duplicate and unnamed fields ---
# list(value = "a", value = "b") keeps both and [[ returns the first,
# so the second would vanish without a word.
expect_error(component("text", value = "a", value = "b"), "duplicate field")
expect_error(component("heading", value = "x", level = 1L, level = 2L),
             "duplicate field")
expect_error(component("text", "hello"), "must all be named")
expect_error(component("link", value = "a", "https://x"), "must all be named")

# --- schema shape ---
check_field <- glinty:::check_field
expect_true(is.list(COMPONENT_SCHEMA))
for (nm in names(COMPONENT_SCHEMA)) {
    for (fname in names(COMPONENT_SCHEMA[[nm]])) {
        spec <- COMPONENT_SCHEMA[[nm]][[fname]]
        expect_true(is.character(spec$type))
        expect_true(spec$type %in% c("string", "strings", "number", "int",
                                     "bool", "enum", "choices", "panels",
                                     "condition", "children", "any"))
        # an enum must say what it allows
        if (identical(spec$type, "enum")) {
            expect_true(length(spec$values) > 0L)
        }
        # a required field with a default is a contradiction
        if (isTRUE(spec$required)) {
            expect_null(spec$default)
        }
        # every default must satisfy its own field spec. A schema that
        # cannot pass its own validator is a bug that would otherwise
        # only surface for whoever first omits that field.
        if (!is.null(spec$default)) {
            expect_silent(check_field(spec$default, spec, nm, fname))
            expect_equal(check_field(spec$default, spec, nm, fname),
                         spec$default)
        }
    }
}

# --- an icon name is a closed set, not free text ---
#
# Every frontend supplies artwork per name, so a name no frontend
# draws is a component that renders nothing. As field("string") that
# was silent in both lowerings at once: an empty span in the browser,
# a question-mark glyph in Flutter.
expect_error(component("icon", name = "sparkles"), "must be one of")
expect_error(component("icon", name = "sparkles"), "play")
for (nm in glinty:::ICON_NAMES) {
    expect_equal(component("icon", name = nm)$name, nm)
}

# --- a multiple select's selection is plural, and stays an array ---
#
# `selected` was field("string"), so c("a", "b") was rejected outright:
# "pick some" was expressible only as "pick one", in the schema, in
# INPUT_META and in both lowerings.
multi <- component("select_input", id = "tags", choices = c("a", "b", "c"),
                   selected = c("a", "c"), multiple = TRUE)
expect_equal(unlist(multi$selected), c("a", "c"))

# A single select still holds one, and says so rather than quietly
# keeping the first.
expect_error(component("select_input", id = "s", choices = c("a", "b"),
                       selected = c("a", "b")),
             "must be a single string")
one <- component("select_input", id = "s", choices = c("a", "b"),
                 selected = "b")
expect_equal(one$selected, "b")
expect_true(is.character(one$selected) && length(one$selected) == 1L)

# The wire form is an array at every length, including one and zero.
# Left to auto_unbox a one-element selection collapses to a bare
# string, so a client parsing it sees a list on Tuesday and a string
# on Wednesday.
as_json <- function(x) {
    as.character(jsonlite::toJSON(unclass_recursive(x), auto_unbox = TRUE))
}
solo <- component("select_input", id = "t", choices = c("a", "b"),
                  selected = "a", multiple = TRUE)
expect_true(grepl('"selected":["a"]', as_json(solo), fixed = TRUE))
none <- component("select_input", id = "t", choices = c("a", "b"),
                  multiple = TRUE)
expect_true(grepl('"selected":[]', as_json(none), fixed = TRUE))
expect_true(grepl('"selected":["a","c"]', as_json(multi), fixed = TRUE))

# and a single select is a bare string on the wire, not a one-element
# array -- the other half of the same contract
expect_true(grepl('"selected":"b"', as_json(one), fixed = TRUE))

# NAs are not selections
expect_error(component("select_input", id = "s", choices = c("a", "b"),
                       selected = c("a", NA), multiple = TRUE),
             "must be strings")

# --- fixtures ---
fx <- component_fixtures()
# Every component in the schema, exactly once. "length >= 20" let the
# list claim exhaustive coverage while missing 13 components, which
# is the kind of gap a shared artifact must not have: a client that
# renders every fixture would still have met only part of the set.
covered <- vapply(fx, function(f) f$component$component, character(1L))
expect_equal(sort(unique(covered)),
             sort(names(glinty:::COMPONENT_SCHEMA)))
# More than one fixture per component is fine and wanted -- text and
# divider carry their variants, plot_output both sizing modes. What
# is not fine is a component with none.
expect_true(length(fx) >= length(glinty:::COMPONENT_SCHEMA))
for (f in fx) {
    expect_true(is.character(f$name) && nzchar(f$name))
    expect_true(is_component(f$component))
    expect_true(is.character(f$notes) && nzchar(f$notes))
}
nms <- vapply(fx, function(f) f$name, character(1L))
expect_equal(anyDuplicated(nms), 0L)

# --- the checked-in JSON matches the R definition ---
# The Dart client cannot call R, so the artifact both sides consume is
# the file. This test is what stops the file falling behind the R
# definition it is generated from.
path <- fixture_json_path()
if (nzchar(path) && file.exists(path)) {
    on_disk <- paste(readLines(path, warn = FALSE), collapse = "\n")
    expect_equal(trimws(on_disk), trimws(fixture_json()))

    # and it parses as the same trees, behind a protocol marker a
    # consumer in another language can check before rendering
    parsed <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    expect_equal(parsed$protocol, glinty:::PROTOCOL_VERSION)
    expect_equal(length(parsed$fixtures), length(fx))
    for (i in seq_along(fx)) {
        expect_equal(parsed$fixtures[[i]]$name, fx[[i]]$name)
        expect_equal(parsed$fixtures[[i]]$component$component,
                     fx[[i]]$component$component)
    }

    # The digest is the artifact identity a copy in another repo pins
    # itself to. Byte-level, because canonical JSON across two
    # languages is not a fight worth having.
    sha <- glinty:::fixture_digest(path)
    expect_true(is.character(sha) && nchar(sha) == 64L)
} else {
    exit_file("fixture JSON not installed")
}
