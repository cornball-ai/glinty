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
    base <- list(
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
                      name = "plot-output-height-only",
                      component = component("plot_output", id = "strip", height = 120L),
                      notes = "the timeline-strip shape: width tracks the container, height is declared"
        ),
                 list(
                      name = "audio-output",
                      component = component("audio_output", id = "player"),
                      notes = "browser has a player element; Flutter needs a package outside the SDK"
        ),
                 list(
                      name = "video-output",
                      component = component("video_output", id = "preview"),
                      notes = "the value's src is a URL on purpose: seeking byte-range-requests it"
        ),
                 list(
                      name = "video-output-config",
                      component = component("video_output", id = "wall",
                controls = FALSE, autoplay = TRUE, muted = TRUE, loop = TRUE),
                      notes = "autoplay rides muted, the one combination browsers allow"
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
                      name = "range-slider",
                      component = component("range_slider", id = "years",
                min = 1990, max = 2030, value = c(2000, 2015), step = 1),
                      notes = paste("one input, two thumbs; its value is the",
                                    "pair [lo, hi] on the wire, both ends on",
                                    "the step grid")
        ),
                 list(
                      name = "button-primary",
                      component = component("button", id = "go", label = "Run",
                variant = "primary"),
                      notes = "emits an event, not an input: there is no value to keep"
        ),
                 list(
                      name = "button-listing",
                      component = component("button", id = "open_row",
                label = "clips", variant = "listing", icon = "folder",
                value = "/media/clips"),
                      notes = "one row of a list: start-aligned, body-coloured, quiet until hovered"
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
                      name = "page-full",
                      component = component("page", title = "Workspace",
                width = "full",
                children = list(component("text", value = "wide"))),
                      notes = "width is a viewport hint; the browser drops the reading column, native may ignore it"
        ),
                 list(
                      name = "workspace-fill",
                      component = component("row", align = "stretch",
                children = list(
                                component("panel", fill = TRUE, grow = 1L,
                        children = list(
                                        component("column", grow = 1L,
                                scroll = TRUE,
                                children = list(component("text", value = "log"))))))),
                      notes = "the workspace shape: stretched row, filled panel, a grown column that scrolls its overflow"
        ),
                 list(
                      name = "text-mono-small",
                      component = component("column", children = list(
                    component("text", value = "00:01:12", variant = "mono"),
                    component("text", value = "fine print",
                              variant = "small"))),
                      notes = "mono aligns by character, small is fine print; both stay semantic"
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
        ),
                 list(
                      name = "shortcut",
                      component = shortcut("play", "space"),
                      notes = paste("renders nothing and takes no space; a bare",
                                    "key waits for focus to leave a text field")
        ),
                 list(
                      name = "shortcut-modified",
                      component = shortcut("save_project", "ctrl+shift+s", typing = TRUE),
                      notes = paste("modifiers are parsed once in R, never by a",
                                    "frontend; ctrl means cmd on a Mac")
        ),
                 list(
                      name = "shortcut-held",
                      component = shortcut("nudge_left", "left", value = "-1",
                hold = TRUE),
                      notes = paste("autorepeat reaches only a binding that asked",
                                    "for it; value rides along as a button's does")
        ),
                 list(
                      name = "image",
                      component = component("image", src = "/static/logo.png",
                alt = "cornball.ai", width = 32L, height = 32L),
                      notes = paste("a picture that is part of the UI, not an",
                                    "output a renderer produced")
        ),
                 list(
                      name = "collapse",
                      component = component("collapse", title = "Parameters",
                open = TRUE,
                children = list(component("text", value = "inside"))),
                      notes = "details/summary in the browser, ExpansionTile in Flutter"
        ),
                 list(
                      name = "collapse-closed",
                      component = component("collapse", title = "API Settings",
                children = list(component("text", value = "hidden"))),
                      notes = "open defaults FALSE; both lowerings start it folded"
        ),
                 list(
                      name = "link-wrapping",
                      component = component("link", href = "https://cornball.ai",
                external = TRUE,
                children = list(component("image", src = "/static/logo.png",
                        alt = "cornball.ai"))),
                      notes = paste("a link around a logo; value= and children=",
                                    "are alternatives, never both")
        ),
                 list(
                      name = "row-sized",
                      component = component("row", gap = 16L, children = list(
                    component("panel", variant = "sidebar", width = 280L,
                              children = list(component("text", value = "side"))),
                    component("column", grow = 1L,
                              children = list(component("text", value = "fills")))
                )),
                      notes = paste("a fixed sidebar beside a filling centre --",
                                    "the shape both migrated apps are built on")
        ),
                 list(
                      name = "button-valued",
                      component = component("button", id = "history_view",
                label = "12:04", value = "entry_7"),
                      notes = paste("the value rides on the event, so one handler",
                                    "serves a list of rows")
        )
    )
    # One fixture per icon name, appended rather than written out.
    # A single "play" fixture let the whole set look covered while the
    # browser drew nothing for any of them -- an empty span passes
    # "does it render" in a way a missing glyph never should.
    c(base, lapply(ICON_NAMES, function(nm) {
        list(name = paste0("icon-", nm),
             component = component("icon", name = nm),
             notes = paste("every frontend must draw", nm,
                           "-- the name is in the closed set, so",
                           "there is no falling back to nothing"))
    }))
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
