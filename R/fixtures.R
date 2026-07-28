# Shared component fixtures.
#
# One set of trees that every lowering must handle. The browser is
# asserted against these here; the Flutter client is asserted against
# the same file in cornball-ai/glinty-dart.
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
              notes = "a titled container; the browser draws a header, Flutter a Card"
        ),
         list(
              name = "empty-column",
              component = component("column", children = list()),
              notes = "a lowering must not crash on an empty container"
        ),
         list(
              name = "text-output",
              component = component("text_output", id = "greeting"),
              notes = "an empty slot; the value arrives later, tagged by kind"
        ),
         list(
              name = "plot-output-responsive",
              component = component("plot_output", id = "scatter"),
              notes = "no dimensions: the client reports its box via measure"
        ),
         list(
              name = "plot-output-fixed",
              component = component("plot_output", id = "fixed", width = 400L,
                                    height = 300L),
              notes = "explicit dimensions, which a native client needs"
        ),
         list(
              name = "audio-output",
              component = component("audio_output", id = "player"),
              notes = "browser has a player element; Flutter needs a package outside the SDK"
        ),
         list(
              name = "text-input",
              component = component("text_input", id = "name", label = "Name:"),
              notes = "emit defaults to live; browser debounces, Flutter uses onChanged"
        ),
         list(
              name = "select-input",
              component = component("select_input", id = "backend",
                                    choices = c(OpenAI = "openai", Local = "local")),
              notes = "choices normalize to value/label however they were written"
        ),
         list(
              name = "select-multiple",
              component = component("select_input", id = "tags",
                                    choices = c("Alpha" = "a", "Beta" = "b", "Gamma" = "c"),
                                    selected = c("a", "c"), multiple = TRUE),
              notes = paste("its value is a list at every length; a",
                            "lowering that picks one control per",
                            "component silently makes this pick-one")
        ),
         list(
              name = "slider-input",
              component = component("slider_input", id = "speed", min = 0.5,
                                    max = 2, value = 1, step = 0.1),
              notes = "numbers, not CSS strings: Flutter derives Slider divisions from step"
        ),
         list(
              name = "button-primary",
              component = component("button", id = "go", label = "Run",
                                    variant = "primary"),
              notes = "emits an event, not an input: there is no value to keep"
        ),
         list(
              name = "password-input",
              component = component("password_input", id = "key",
                                    label = "API Key"),
              notes = "no value field exists, so no secret can reach the wire"
        ),
         list(
              name = "tabset",
              component = component("tabset", id = "tabs", panels = list(
                    list(title = "Text",
                         children = list(component("text_output", id = "body"))),
                    list(title = "Raw",
                         children = list(component("verbatim_output",
                                id = "raw")))
                )),
              notes = "Flutter and the browser both retain hidden panel state"
        ),
         list(
              name = "conditional-panel",
              component = component("conditional_panel",
                                    condition = input_is("backend", "openai"),
                                    children = list(
                    component("text_input", id = "api_base",
                              label = "API URL"))),
              notes = "the condition is data, evaluated by whoever renders it"
        ),
         # The rest of the schema. Every component appears here at
         # least once, and a test asserts that against
         # COMPONENT_SCHEMA -- "every component, once" was a claim
         # this list did not keep until it was checked.
         list(
              name = "page",
              component = component("page", title = "Fixture page",
                                    children = list(
                    component("heading", value = "Hi", level = 1L))),
              notes = "the root every client is handed in welcome"
        ),
         list(
              name = "textarea-input",
              component = component("textarea_input", id = "notes",
                                    label = "Notes:", value = "line one",
                                    rows = 6L, placeholder = "why"),
              notes = "rows is a count, not a CSS height"
        ),
         list(
              name = "number-input",
              component = component("number_input", id = "k",
                                    label = "Clusters:", value = 3,
                                    min = 1, max = 10, step = 1),
              notes = paste("bounds and step are numbers a frontend may",
                            "spend on a spinner, a slider, or a hint")
        ),
         list(
              name = "checkbox-input",
              component = component("checkbox_input", id = "save",
                                    label = "Save results", value = TRUE),
              notes = "a checkbox starts at a real boolean, never NULL"
        ),
         list(
              name = "radio-buttons",
              component = component("radio_buttons", id = "mode",
                                    label = "Mode:",
                                    choices = c(Fast = "fast", Careful = "careful"),
                                    selected = "careful"),
              notes = "one value for the group, from the selected member"
        ),
         list(
              name = "date-input",
              component = component("date_input", id = "start",
                                    label = "Start:", value = "2026-07-27",
                                    min = "2026-01-01", max = "2026-12-31"),
              notes = "a date is a YYYY-MM-DD string on the wire, not a class"
        ),
         list(
              name = "file-input",
              component = component("file_input", id = "dataset",
                                    label = "CSV:", accept = ".csv",
                                    multiple = TRUE),
              notes = "its value arrives over HTTP, not the socket"
        ),
         list(
              name = "download-button",
              component = component("download_button", id = "report",
                                    label = "Download", variant = "primary"),
              notes = paste("a press asks for a transfer ticket, not an",
                            "event: the press IS the download")
        ),
         list(
              name = "verbatim-output",
              component = component("verbatim_output", id = "log"),
              notes = "same text kind as text_output; only the display differs"
        ),
         list(
              name = "table-output",
              component = component("table_output", id = "results"),
              notes = "structure on the wire (header + rows), never markup"
        ),
         list(
              name = "image-output",
              component = component("image_output", id = "cover",
                                    alt = "album art"),
              notes = "an image the app supplies, unlike a plot it renders"
        ),
         list(
              name = "html-output",
              component = component("html_output", id = "details"),
              notes = "browser-only: the html kind has no widget equivalent"
        ),
         list(
              name = "ui-output",
              component = component("ui_output", id = "panel"),
              notes = "the slot render_ui() fills with a component tree"
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
    # Wrapped rather than a bare array so a consumer in another
    # language can check it is answering to the protocol it was written
    # against, instead of silently rendering a newer shape. A copy of
    # this file that has drifted is worse than no copy: both repos pass
    # independently, against different data.
    as.character(jsonlite::toJSON(list(protocol = PROTOCOL_VERSION,
                                       fixtures = payload),
                                  auto_unbox = TRUE, pretty = TRUE,
                                  null = "null"))
}

#' Digest of the fixture file as bytes
#'
#' Byte-level rather than structural, because the consumers are in
#' different languages and canonical JSON serialization is not
#' something to litigate across two of them. The file is the artifact;
#' its sha256 is its identity.
#'
#' @param path character file to hash; defaults to the installed copy
#' @return character sha256, or NA when the file is absent
#' @keywords internal
fixture_digest <- function(path = fixture_json_path()) {
    if (!nzchar(path) || !file.exists(path)) {
        return(NA_character_)
    }
    digest::digest(file = path, algo = "sha256")
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
