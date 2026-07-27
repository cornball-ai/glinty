# Shared component fixtures.
#
# One set of trees that every lowering must handle. The browser and
# flitR are asserted against these in stage 1; a Dart client is
# asserted against the same list at stage 6.
#
# The point is not coverage for its own sake. It is that a component
# only counts as frontend-neutral once more than one lowering has had
# to render it, and a fixture list is what stops that check from being
# something everyone means to do later.
#
# The list is defined in R and *checked in as JSON* at
# inst/fixtures/components.json. The Dart client lives in another
# repository and cannot call R, so the artifact both sides consume has
# to be data. write_fixture_json() regenerates it and a test fails if
# the two drift, which keeps the R definition authoritative without
# making the JSON a stale copy.

#' Component fixtures every lowering must handle
#'
#' Each entry is list(name, component, notes). Lowering tests iterate
#' this, so adding a component here obliges every frontend to answer
#' for it -- render it, or refuse it by name.
#'
#' @return list of fixtures
#' @keywords internal
component_fixtures <- function() {
    list(
         list(name = "text", component = component("text", value = "hello"),
              notes = "the simplest leaf; every frontend renders it"),
         list(
              name = "text-muted",
              component = component("text", value = "quiet", variant = "muted"),
              notes = "variant is semantic; each frontend picks its own muting"
        ),
         list(
              name = "heading",
              component = component("heading", value = "Title", level = 1L),
              notes = "level is 1..4, not a tag name"
        ),
         list(
              name = "link",
              component = component("link", value = "cornball.ai",
                                    href = "https://cornball.ai"),
              notes = "href is data; a native frontend opens a browser"
        ),
         list(
              name = "divider",
              component = component("divider"),
              notes = "no required fields; a lowering must handle the bare case"
        ),
         list(
              name = "divider-labelled",
              component = component("divider", label = "or",
                                    variant = "labelled"),
              notes = "the 'or' separator both migrated apps use"
        ),
         list(
              name = "spacer",
              component = component("spacer", size = 2L),
              notes = "size is in theme spacing units, not pixels"
        ),
         list(
              name = "icon",
              component = component("icon", name = "play"),
              notes = "named, not a glyph or a path; frontends own the artwork"
        ),
         list(
              name = "row",
              component = component("row", gap = 12L, children = list(
                    component("text", value = "a"),
                    component("text", value = "b")
                )),
              notes = "nesting; gap is a number, not a CSS string"
        ),
         list(
              name = "column-nested",
              component = component("column", children = list(
                    component("heading", value = "Section"),
                    component("row", children = list(
                            component("text", value = "x"),
                            component("spacer"),
                            component("text", value = "y")
                        ))
                )),
              notes = "recursion depth > 1, which is where lowerings drift"
        ),
         list(
              name = "panel-card",
              component = component("panel", variant = "card",
                                    title = "Results",
                                    children = list(component("text", value = "body"))),
              notes = "a titled container; the browser draws a header, flitR may not"
        ),
         list(
              name = "empty-column",
              component = component("column", children = list()),
              notes = "a lowering must not crash on an empty container"
        ),
         list(
              name = "raw_html",
              component = component("raw_html", html = "<details>x</details>"),
              notes = "browser renders; every other frontend must refuse by name"
        )
    )
}

#' Serialize the fixtures to JSON
#'
#' The wire form of every fixture, plus its name and note, as one
#' document. This is what a client in another language consumes.
#'
#' @return character JSON
#' @keywords internal
fixture_json <- function() {
    payload <- lapply(component_fixtures(), function(f) {
        list(name = f$name, notes = f$notes,
             component = unclass_recursive(f$component))
    })
    as.character(jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = TRUE,
                                  null = "null"))
}

#' Path to the checked-in fixture JSON
#'
#' @return character path, or "" when the package is not installed
#' @keywords internal
fixture_json_path <- function() {
    system.file("fixtures", "components.json", package = "glinty")
}

#' Regenerate the checked-in fixture JSON
#'
#' Run after changing component_fixtures(). A test compares the file
#' against fixture_json() and fails on drift, so the JSON cannot
#' silently fall behind the R definition.
#'
#' @param path character destination; defaults to the source tree
#' @return the path, invisibly
#' @keywords internal
write_fixture_json <- function(path = "inst/fixtures/components.json") {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(fixture_json(), path)
    invisible(path)
}
