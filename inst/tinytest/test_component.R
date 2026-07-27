component <- glinty:::component
is_component <- glinty:::is_component
check_children <- glinty:::check_children
component_fixtures <- glinty:::component_fixtures
COMPONENT_SCHEMA <- glinty:::COMPONENT_SCHEMA
unclass_recursive <- glinty:::unclass_recursive

# --- construction ---
tx <- component("text", value = "hello")
expect_true(is_component(tx))
expect_equal(tx$component, "text")
expect_equal(tx$value, "hello")

# --- required fields are enforced where the component is written ---
expect_error(component("text"), "missing required field")
expect_error(component("link", value = "x"), "missing required field")
expect_error(component("link", value = "x"), "href")
expect_error(component("heading"), "missing required field")

# --- unknown fields are rejected, not silently carried ---
# A typo'd field would otherwise travel to every client and be ignored
# by all of them, which is the worst kind of silent failure.
expect_error(component("text", value = "x", colour = "red"), "unknown field")
expect_error(component("text", value = "x", colour = "red"), "Allowed:")

expect_error(component("nonexistent", value = "x"), "unknown component type")

# --- optional defaults are filled ---
expect_equal(component("text", value = "x")$variant, "normal")
expect_equal(component("heading", value = "x")$level, 2L)
expect_equal(component("icon", name = "play")$size, 16L)
expect_equal(component("spacer")$size, 1L)
expect_false(component("link", value = "a", href = "b")$external)

# an explicit value beats the default
expect_equal(component("heading", value = "x", level = 4L)$level, 4L)

# --- an absent optional with no default is absent, not null ---
# NULL fields would serialize as JSON null and force every client to
# distinguish "unset" from "explicitly nothing".
plain <- component("text", value = "x")
expect_false("id" %in% names(plain))
expect_true("variant" %in% names(plain))

gapless <- component("row", children = list())
expect_false("gap" %in% names(gapless))

# --- children must be components ---
expect_error(check_children(list("a bare string"), "row"), "not a component")
expect_error(check_children(list("a bare string"), "row"),
             "Wrap plain strings in text")
expect_error(check_children(list(component("text", value = "ok"), 42), "row"),
             "child 2")
# NULLs are dropped, so conditional children compose
kids <- check_children(list(component("text", value = "a"), NULL,
                            component("text", value = "b")), "row")
expect_equal(length(kids), 2L)
# and the result is unnamed, so it serializes as a JSON array
expect_null(names(kids))

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
expect_true(grepl('"component":"heading"', json, fixed = TRUE))
# children survives as an array even at length 1
one <- unclass_recursive(component("row",
                                   children = list(component("text",
                                                             value = "solo"))))
expect_true(grepl('"children":[{', as.character(jsonlite::toJSON(one,
                                                    auto_unbox = TRUE)),
                  fixed = TRUE))

# --- password_input cannot carry a value, by schema ---
# The v3 answer to a secret rendered into page source: a field that
# cannot be expressed cannot leak. Asserted once the input components
# land; for now, hold the line that the schema is the mechanism.
expect_true(is.list(COMPONENT_SCHEMA))
for (nm in names(COMPONENT_SCHEMA)) {
    sch <- COMPONENT_SCHEMA[[nm]]
    expect_true(is.character(sch$required))
    expect_true(is.list(sch$optional))
    # no field may be both required and optional
    expect_equal(length(intersect(sch$required, names(sch$optional))), 0L)
}

# --- fixtures are well-formed and every one constructs ---
fx <- component_fixtures()
expect_true(length(fx) >= 10L)
for (f in fx) {
    expect_true(is.character(f$name) && nzchar(f$name))
    expect_true(is_component(f$component))
    # every fixture explains why it earns its place
    expect_true(is.character(f$notes) && nzchar(f$notes))
}
# names are unique, so a failing lowering test names one fixture
nms <- vapply(fx, function(f) f$name, character(1L))
expect_equal(anyDuplicated(nms), 0L)

# every fixture survives the wire round trip
for (f in fx) {
    j <- as.character(jsonlite::toJSON(unclass_recursive(f$component),
                                       auto_unbox = TRUE))
    back <- jsonlite::fromJSON(j, simplifyVector = FALSE)
    expect_equal(back$component, f$component$component)
}
