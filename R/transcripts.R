# Shared wire transcripts.
#
# component_fixtures() covers what a tree looks like. These cover what
# a *conversation* looks like: the frames that cross the wire, in
# order, for the exchanges every client has to get right.
#
# Both clients replay them. A client that renders every component
# correctly and mishandles the opening exchange is still broken, and
# nothing in the component fixtures would notice.

#' The SHA-256 of a component tree's wire form
#'
#' Sent in `welcome` and embedded in any pre-rendered document, so a
#' client can tell whether markup it was handed describes the tree it
#' has just been sent. Canonical means the serializer that produces
#' the wire form, so the hash is over exactly the bytes a client
#' parses.
#'
#' @param ui a page component
#' @return character lowercase hex sha256
#' @keywords internal
ui_revision <- function(ui) {
    json <- as.character(jsonlite::toJSON(unclass_recursive(ui),
            auto_unbox = TRUE, null = "null"))
    digest::digest(json, algo = "sha256", serialize = FALSE)
}

#' Wire transcripts every client must handle
#'
#' Each entry is list(name, notes, frames), where frames are
#' list(dir, message) and dir is "in" (client to server) or "out"
#' (server to client).
#'
#' @return list of transcripts
#' @keywords internal
wire_transcripts <- function() {
    simple_ui <- component("page", title = "Demo", children = list(
            component("heading", value = "Demo", level = 1L),
            component("text_input", id = "name", label = "Name:"),
            component("text_output", id = "greeting")
        ))
    rev <- ui_revision(simple_ui)

    list(
         list(
              name = "hello-welcome",
              notes = paste("the opening exchange; the client declares what",
                            "it can render, the server answers with the tree",
                            "and its revision"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "hello", protocol = PROTOCOL_VERSION,
                        client = "example/0.0.1",
                        components = I(c("page", "heading", "text_input",
                                "text_output")),
                        kinds = I(c("text")),
                        features = I(c("measure"))
                    )),
                            list(dir = "out", message = list(
                        type = "welcome", session = "s1",
                        protocol = PROTOCOL_VERSION,
                        ui_revision = rev,
                        ui = unclass_recursive(simple_ui)
                    ))
            )
        ),
         list(
              name = "hello-welcome-hydrated",
              notes = paste("the same exchange when the client already has",
                            "matching pre-rendered markup: it adopts rather",
                            "than rebuilds, and sends nothing"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "hello", protocol = PROTOCOL_VERSION,
                        client = "glinty-js/0.5.0",
                        prerendered = rev
                    )),
                            list(dir = "out", message = list(
                        type = "welcome", session = "s2",
                        protocol = PROTOCOL_VERSION,
                        ui_revision = rev,
                        ui = unclass_recursive(simple_ui)
                    ))
            )
        ),
         list(
              name = "revision-mismatch",
              notes = paste("pre-rendered markup from a different tree; the",
                            "client must discard it and build from welcome",
                            "rather than patching a stale DOM"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "hello", protocol = PROTOCOL_VERSION,
                        client = "glinty-js/0.5.0",
                        prerendered = strrep("0", 64L)
                    )),
                            list(dir = "out", message = list(
                        type = "welcome", session = "s3",
                        protocol = PROTOCOL_VERSION,
                        ui_revision = rev,
                        ui = unclass_recursive(simple_ui)
                    ))
            )
        ),
         list(
              name = "protocol-mismatch",
              notes = paste("a server speaking a newer protocol; the client",
                            "refuses visibly rather than rendering the half",
                            "it recognises"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "hello", protocol = PROTOCOL_VERSION,
                        client = "glinty-js/0.5.0"
                    )),
                            list(dir = "out", message = list(
                        type = "welcome", session = "s4",
                        protocol = PROTOCOL_VERSION + 1L,
                        ui_revision = rev,
                        ui = unclass_recursive(simple_ui)
                    ))
            )
        ),
         list(
              name = "input-then-output",
              notes = paste("a user edit and the output it drives; the value",
                            "is typed by kind, not by DOM property"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "input", id = "name", value = "Troy"
                    )),
                            list(dir = "out", message = list(
                        type = "output", id = "greeting", kind = "text",
                        value = "Hello, Troy"
                    ))
            )
        ),
         list(
              name = "measure-then-image",
              notes = paste("a client-sized output reporting its box, and the",
                            "image that comes back at that size; replaces the",
                            "reserved ..clientdata_output_* inputs"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "measure", id = "scatter", width = 640L,
                        height = 480L
                    )),
                            list(dir = "out", message = list(
                        type = "output", id = "scatter", kind = "image",
                        value = list(src = "data:image/png;base64,AAAA",
                                     width = 640L, height = 480L)
                    ))
            )
        )
    )
}

#' Serialize the transcripts to JSON
#'
#' @return character JSON
#' @keywords internal
transcript_json <- function() {
    as.character(jsonlite::toJSON(
                                  list(protocol = PROTOCOL_VERSION, transcripts = wire_transcripts()),
                                  auto_unbox = TRUE, pretty = TRUE, null = "null"))
}

#' Path to the checked-in transcript JSON
#'
#' @return character path, or "" when the package is not installed
#' @keywords internal
transcript_json_path <- function() {
    system.file("fixtures", "transcripts.json", package = "glinty")
}

#' Regenerate the checked-in transcript JSON
#'
#' Run after changing wire_transcripts(). A test compares the file
#' against transcript_json() and fails on drift.
#'
#' @param path character destination
#' @return the path, invisibly
#' @keywords internal
write_transcript_json <- function(path = "inst/fixtures/transcripts.json") {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(transcript_json(), path)
    invisible(path)
}
