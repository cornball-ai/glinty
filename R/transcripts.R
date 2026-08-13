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
#' has just been sent.
#'
#' The value is opaque to clients: they compare it for string
#' equality and never compute, parse, or shape-check it. The hash
#' algorithm and the canonical serialization (the same one that
#' produces the wire form) bind this server alone, which is what
#' keeps R's JSON habits out of every other language.
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
                            "it can render, the server answers with the",
                            "theme, the tree and its revision. The theme",
                            "here is glinty's default token set; a",
                            "themeless app omits the field and each",
                            "frontend's own defaults apply"),
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
                        theme = theme_wire(app_theme()),
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
              name = "hello-authenticated",
              notes = paste("the opening exchange under run_app(auth = ):",
                            "hello carries an opaque token, the verifier",
                            "turns it into session$principal, and the",
                            "welcome is otherwise unchanged. A refused",
                            "token gets one error frame and a closed",
                            "socket instead"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "hello", protocol = PROTOCOL_VERSION,
                        client = "glinty-js/0.5.0",
                        token = "eyJhb.example.token"
                    )),
                            list(dir = "out", message = list(
                        type = "welcome", session = "s6",
                        protocol = PROTOCOL_VERSION,
                        ui_revision = rev,
                        ui = unclass_recursive(simple_ui)
                    ))
            )
        ),
         list(
              name = "hello-refused",
              notes = paste("a hello whose token the verifier rejected:",
                            "one id-less error frame naming the reason,",
                            "then the server closes the socket. Every",
                            "client draws this; a refusal nobody sees is",
                            "the failure mode the visible-refusal rule",
                            "exists to prevent"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "hello", protocol = PROTOCOL_VERSION,
                        client = "glinty-js/0.5.0",
                        token = "expired.or.wrong"
                    )),
                            list(dir = "out", message = list(
                        type = "error", id = NULL,
                        message = "authentication failed"
                    ))
            )
        ),
         list(
              name = "ticket-grant",
              notes = paste("a transfer credential: the client asks over",
                            "the socket, the grant is scoped to one session,",
                            "one resource, one purpose, and expires seconds",
                            "(relative TTL) later. Single use: redeeming it",
                            "consumes it, success or not"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "ticket", id = "dataset",
                        purpose = "upload"
                    )),
                            list(dir = "out", message = list(
                        type = "ticket", id = "dataset",
                        purpose = "upload",
                        token = "tk_9c1f2ab34d56e78f90a1b2c3d4e5f607",
                        expires = 30L
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
              name = "button-event",
              notes = paste("a button press; an event carries no value",
                            "because there is no state the server keeps,",
                            "only the fact that it happened"),
              frames = list(
                            list(dir = "in", message = list(type = "event", id = "go")),
                            list(dir = "out", message = list(
                        type = "output", id = "count", kind = "text",
                        value = "1"
                    ))
            )
        ),
         list(
              name = "ticket-refused",
              notes = paste("the server will not grant this transfer:",
                            "a ticket frame carrying `error` where a grant",
                            "carries `token`. Answered on the channel the",
                            "request was made on, so the client hands it to",
                            "the control that asked rather than guessing",
                            "which element an id meant -- and so `error`",
                            "keeps meaning one thing, a render failure",
                            "scoped to an output"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "ticket", id = "report",
                        purpose = "download"
                    )),
                            list(dir = "out", message = list(
                        type = "ticket", id = "report",
                        purpose = "download",
                        error = "too many pending transfers"
                    ))
            )
        ),
         list(
              name = "valued-event",
              notes = paste("a press from a list row. The value rides on",
                            "the event so one handler serves every row --",
                            "the press says which. A client that drops it",
                            "reports a press the server cannot place, which",
                            "is why the field is on the wire and not in",
                            "the id"),
              frames = list(
                            list(dir = "in", message = list(type = "event",
                        id = "history_view", value = "entry_7")),
                            list(dir = "out", message = list(
                        type = "output", id = "transcription", kind = "text",
                        value = "the seventh transcription"
                    ))
            )
        ),
         list(
              name = "measure-then-image",
              notes = paste("a client-sized output reporting its box in",
                            "logical pixels with its device pixel ratio, and",
                            "the image that comes back: rasterized at 2x",
                            "behind that src, sized in logical pixels in the",
                            "value; replaces the reserved",
                            "..clientdata_output_* inputs"),
              frames = list(
                            list(dir = "in", message = list(
                        type = "measure", id = "scatter", width = 640L,
                        height = 480L, dpr = 2L
                    )),
                            list(dir = "out", message = list(
                        type = "output", id = "scatter", kind = "image",
                        value = list(src = "data:image/png;base64,AAAA",
                                     width = 640L, height = 480L)
                    ))
            )
        ),
         list(
              name = "audio-output",
              notes = paste("an audio value carries what it is, not just",
                            "where it is: a browser sniffs the bytes and",
                            "needs no media type, which is how the field",
                            "went missing, but a native client hands the",
                            "source to a platform player that asks"),
              frames = list(
                            list(dir = "in", message = list(type = "event",
                        id = "generate")),
                            list(dir = "out", message = list(
                        type = "output", id = "player", kind = "audio",
                        value = list(src = "data:audio/wav;base64,UklGRg",
                                     mime = "audio/wav", duration = 1.5)
                    ))
            )
        ),
         list(
              name = "video-output",
              notes = paste("a video value is a URL plus its type: seeking",
                            "works by byte-range requests against a URL,",
                            "which is why the src is never embedded bytes.",
                            "The video_update that follows drives playback",
                            "without replacing the element -- an output",
                            "message swaps the video, this moves inside it"),
              frames = list(
                            list(dir = "in", message = list(type = "event",
                        id = "render")),
                            list(dir = "out", message = list(
                        type = "output", id = "preview", kind = "video",
                        value = list(src = "/static/cut.mp4",
                                     mime = "video/mp4", duration = 4.2)
                    )),
                            list(dir = "out", message = list(
                        type = "video_update", id = "preview",
                        current_time = 1.5, playing = TRUE))
            )
        ),
         list(
              name = "event-then-ui",
              notes = paste("dynamic UI: an output whose value is a component",
                            "tree; every client builds it the way it builds",
                            "welcome.ui, bindings included"),
              frames = list(
                            list(dir = "in", message = list(type = "event", id = "more")),
                            list(dir = "out", message = list(
                        type = "output", id = "panel", kind = "ui",
                        value = unclass_recursive(component("column",
                                children = list(
                                    component("heading", value = "Details",
                                        level = 4L),
                                    component("text_input", id = "extra",
                                        label = "Extra:")
                                )))
                    ))
            )
        ),
         list(
              name = "input-update",
              notes = paste("a server-driven input change; the client applies",
                            "it widget-aware and never echoes an input frame",
                            "back, since the server already synced its copy"),
              frames = list(
                            list(dir = "in", message = list(type = "event", id = "randomize")),
                            list(dir = "out", message = list(
                        type = "input_update", id = "txt", value = "corn"
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
