#' Create an output message
#'
#' An output's current value, typed by what the renderer produced --
#' not by the DOM property a browser would patch. How a value is
#' displayed belongs to the receiving component; `kind` only says
#' what the value is.
#'
#' @param id character output ID
#' @param kind character one of text, html, table, image, audio, ui
#' @param value the renderer's value
#' @return character JSON string
#' @keywords internal
output_msg <- function(id, kind, value) {
    as.character(jsonlite::toJSON(
                                  list(type = "output", id = id, kind = kind, value = value),
                                  auto_unbox = TRUE, null = "null"
        ))
}

#' Create a typed input-update message
#'
#' Inputs get typed messages instead of raw DOM patches: the client
#' applies them widget-aware (skipping a focused element's value,
#' rebuilding select options) and never re-emits input events.
#'
#' @param id character input ID
#' @param fields named list of update fields (value, label, choices,
#'   selected, min, max, step) with NULLs already dropped
#' @return character JSON string
#' @keywords internal
input_update_msg <- function(id, fields) {
    msg <- c(list(type = "input_update", id = id), fields)
    as.character(jsonlite::toJSON(msg, auto_unbox = TRUE, null = "null"))
}

#' Create a custom message
#'
#' The server-to-app-JavaScript channel: the client looks up handler
#' among those registered with Glinty.addCustomMessageHandler() and
#' calls it with value.
#'
#' @param handler character handler name
#' @param value the payload, serialized as JSON
#' @return character JSON string
#' @keywords internal
custom_msg <- function(handler, value) {
    as.character(jsonlite::toJSON(
                                  list(type = "custom", handler = handler, value = value),
                                  auto_unbox = TRUE, null = "null"
        ))
}

#' Create a modal open message
#'
#' @param title character heading, or NULL
#' @param body list of unclassed tag trees
#' @param footer an unclassed tag tree, or NULL
#' @param easy_close logical dismiss on backdrop click or Escape
#' @return character JSON string
#' @keywords internal
modal_msg <- function(title, body, footer, easy_close) {
    as.character(jsonlite::toJSON(
                                  list(type = "modal", action = "show", title = title,
                                       body = body, footer = footer, easy_close = easy_close),
                                  auto_unbox = TRUE, null = "null"
        ))
}

#' Create a modal close message
#'
#' @return character JSON string
#' @keywords internal
modal_close_msg <- function() {
    as.character(jsonlite::toJSON(list(type = "modal", action = "hide"),
                                  auto_unbox = TRUE))
}

#' Create a progress message
#'
#' @param action character "show", "update" or "hide"
#' @param handle a progress handle
#' @return character JSON string
#' @keywords internal
progress_msg <- function(action, handle) {
    msg <- list(type = "progress", action = action, id = handle$id)
    if (!identical(action, "hide")) {
        msg$message <- handle$message
        msg$detail <- handle$detail
        msg$value <- handle$value
    }
    as.character(jsonlite::toJSON(msg, auto_unbox = TRUE, null = "null"))
}

#' Create a ticket grant message
#'
#' @param id character resource id the ticket covers
#' @param purpose "upload" or "download"
#' @param token character the ticket
#' @param expires numeric TTL in seconds (relative, so no clock sync
#'   is asked of the client)
#' @return character JSON string
#' @keywords internal
ticket_msg <- function(id, purpose, token, expires) {
    as.character(jsonlite::toJSON(
                                  list(type = "ticket", id = id, purpose = purpose, token = token,
                                       expires = expires),
                                  auto_unbox = TRUE
        ))
}

#' Create an error message
#'
#' @param id character output ID, or NULL for session-level errors
#' @param message character error text
#' @return character JSON string
#' @keywords internal
error_msg <- function(id, message) {
    as.character(jsonlite::toJSON(
                                  list(type = "error", id = id, message = message),
                                  auto_unbox = TRUE, null = "null"
        ))
}

#' Create the welcome message
#'
#' The bootstrap, and the first frame a client receives: the session
#' id, the protocol version, and the canonical component tree with
#' its revision. A client that ignores everything else and renders
#' welcome.ui is correct.
#'
#' The tree and revision come from .globals, set once by run_app().
#' Both are omitted when unset (bare test sessions), never in a
#' served app.
#'
#' @param session_id character session ID
#' @param resumed logical TRUE when a detached session was resumed,
#'   FALSE when a resume was refused (the client reloads), NULL for a
#'   fresh session
#' @return character JSON string
#' @keywords internal
welcome_msg <- function(session_id, resumed = NULL) {
    msg <- list(type = "welcome", session = session_id,
                protocol = PROTOCOL_VERSION)
    if (!is.null(.globals$welcome_theme)) {
        msg$theme <- .globals$welcome_theme
    }
    if (!is.null(.globals$welcome_revision)) {
        msg$ui_revision <- .globals$welcome_revision
    }
    if (!is.null(.globals$welcome_ui)) {
        msg$ui <- .globals$welcome_ui
    }
    if (!is.null(resumed)) {
        msg$resumed <- resumed
    }
    as.character(jsonlite::toJSON(msg, auto_unbox = TRUE, null = "null"))
}

#' Dispatch one client message to a session
#'
#' Parses the JSON text frame and routes by type: hello records the
#' client's declared capabilities, input applies a single input
#' change, event bumps an event counter. hello no longer carries
#' input values -- under v3 the server built the tree, so it seeded
#' the defaults itself before the client ever connected.
#' Malformed or unknown messages queue an error message instead of
#' raising. Does not flush; the caller flushes after dispatch.
#'
#' @param session a glinty_session
#' @param txt character JSON from one WebSocket text frame
#' @return invisible(NULL)
#' @keywords internal
dispatch_client_message <- function(session, txt) {
    msg <- tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE),
                    error = function(e) NULL)
    if (is.null(msg) || is.null(msg$type)) {
        session$send(error_msg(NULL, "malformed message"))
        return(invisible(NULL))
    }
    if (identical(msg$type, "hello")) {
        handle_hello(session, msg)
    } else if (identical(msg$type, "input")) {
        # ids opening with ".." were protocol 2's reserved measurement
        # channel; refusing them keeps a client from spoofing session
        # measurement state through the input path.
        if (is.character(msg$id) && !startsWith(msg$id, "..")) {
            handle_input(session, msg$id, normalize_value(msg$value))
        }
    } else if (identical(msg$type, "event")) {
        if (is.character(msg$id)) {
            handle_event(session, msg$id)
        }
    } else if (identical(msg$type, "measure")) {
        handle_measure(session, msg)
    } else if (identical(msg$type, "ticket")) {
        if (is.character(msg$id) && length(msg$id) == 1L &&
            nzchar(msg$id) && is.character(msg$purpose) &&
            msg$purpose %in% c("upload", "download")) {
            t <- issue_ticket(session, msg$id, msg$purpose)
            if (is.null(t)) {
                # At the live-ticket cap. Answer, rather than drop:
                # a client waiting on a grant that never comes leaves
                # its upload control disabled forever, which is the
                # silent failure this protocol keeps refusing to
                # ship. The error is scoped to the resource so the
                # client can re-enable exactly that control.
                session$send(error_msg(msg$id, "too many pending transfers"))
            } else {
                session$send(ticket_msg(msg$id, msg$purpose, t$token,
                                        t$expires))
            }
        }
    } else {
        session$send(error_msg(NULL,
                               paste0("unknown message type: ", msg$type)))
    }
    invisible(NULL)
}

#' Record what a client declared in hello
#'
#' A declaration, not a negotiation: the server sends the whole tree
#' regardless and the client draws placeholders for what it cannot
#' render. Recording it lets render_ui() branch per session and makes
#' the gap diagnosable. The welcome is sent by the session-start
#' path, never from here, so a redeclaring reconnect cannot trigger a
#' second bootstrap.
#'
#' @param session a glinty_session
#' @param msg decoded hello message
#' @return invisible(NULL)
#' @keywords internal
handle_hello <- function(session, msg) {
    if (is.character(msg$client)) {
        session$client <- msg$client
    } else {
        session$client <- NULL
    }
    session$capabilities <- list(
                                 components = as.character(unlist(msg$components)),
                                 kinds = as.character(unlist(msg$kinds)),
                                 features = as.character(unlist(msg$features))
    )
    invisible(NULL)
}

#' Record a client measurement for one output
#'
#' Width and height arrive in logical pixels, dpr as physical pixels
#' per logical one (absent means 1). Last write wins, per id, into
#' session state -- element state on the client may come and go with
#' rebuilds, but the session's idea of "how big is this output" only
#' changes when a client reports a new box. A measurement for an id
#' with no renderer yet is stored and harmless: dynamic UI races
#' layout, and the output it names may be about to exist.
#'
#' Stored as a reactive value, so a renderer that read it re-renders
#' exactly when a new box arrives.
#'
#' @param session a glinty_session
#' @param msg decoded measure message
#' @return invisible(NULL)
#' @keywords internal
handle_measure <- function(session, msg) {
    if (!is.character(msg$id) || length(msg$id) != 1L || !nzchar(msg$id)) {
        return(invisible(NULL))
    }
    w <- suppressWarnings(as.numeric(msg$width))
    h <- suppressWarnings(as.numeric(msg$height))
    dpr <- if (is.null(msg$dpr)) {
        1
    } else {
        suppressWarnings(as.numeric(msg$dpr))
    }
    ok <- function(x, lo, hi) {
        length(x) == 1L && is.finite(x) && x >= lo && x <= hi
    }
    # Zero is not a size, it is the absence of one; a client following
    # the spec never sends it, and one that does must not shrink a
    # plot for an element that is about to come back.
    #
    # The upper bounds are resource caps, not layout opinions: a
    # measurement sizes a raster the server will allocate, so the
    # physical pixel count is the thing to bound. 8192 logical per
    # side covers an 8K desktop; dpr 8 is past any real device; and
    # 32 megapixels of physical area (a 4K display at dpr 2, with
    # room) caps the buffer at ~128 MB no matter how the factors
    # combine. Anything outside is ignored wholesale -- a hostile
    # client gets a stale plot, not an allocation.
    if (!ok(w, 1, 8192) || !ok(h, 1, 8192) || !ok(dpr, 0.1, 8) ||
        !ok(w * dpr, 1, 16384) || !ok(h * dpr, 1, 16384) ||
        !ok(w * dpr * h * dpr, 1, 33554432)) {
        return(invisible(NULL))
    }
    box <- list(width = w, height = h, dpr = dpr)
    env <- session$measures
    if (!exists(msg$id, envir = env)) {
        # Unknown ids are stored because dynamic UI races layout, but
        # storage is bounded: a client inventing ids must not grow
        # session memory without limit. No real page holds hundreds
        # of measured outputs. all.names, or every dot-prefixed id
        # slips past the count while exists() sees it fine -- a cap
        # that hidden names bypass is not a cap.
        if (length(ls(env, all.names = TRUE)) >= 256L) {
            return(invisible(NULL))
        }
        env[[msg$id]] <- reactive_val(box)
    } else {
        env[[msg$id]](box)
    }
    invisible(NULL)
}

#' Read an output's client-reported box, reactively
#'
#' @param session a glinty_session
#' @param id character output ID
#' @return list(width, height, dpr), or NULL before any report
#' @keywords internal
measured_box <- function(session, id) {
    env <- session$measures
    if (!exists(id, envir = env)) {
        # Creating the reactive value on first read means the read is
        # tracked even before a client reports, so the first
        # measurement re-renders the plot that is waiting for it.
        env[[id]] <- reactive_val(NULL)
    }
    env[[id]]()
}

#' Normalize a JSON-decoded input value
#'
#' fromJSON(simplifyVector = FALSE) leaves arrays as lists (e.g.
#' multi-select values); collapse homogeneous ones to vectors.
#'
#' Only *unnamed* lists collapse. A JSON object decodes to a named
#' list, and unlisting one would throw away the names and coerce
#' mixed types to a single mode -- exactly the wrong thing for an
#' object-valued input like Glinty.setInputValue("clip", {data: ...,
#' size: ...}), which arrives as a named list instead.
#'
#' @param value a decoded JSON value
#' @return an R value suitable for a reactive_val
#' @keywords internal
normalize_value <- function(value) {
    if (is.list(value) && is.null(names(value))) {
        atomic <- all(vapply(value, function(v) {
            is.atomic(v) && length(v) == 1L
        }, logical(1L)))
        if (atomic) {
            return(unlist(value, use.names = FALSE))
        }
    }
    value
}

#' Strip classes recursively so jsonlite serializes tag trees cleanly
#'
#' @param x a UI tree or subtree
#' @return the same structure with classes removed
#' @keywords internal
unclass_recursive <- function(x) {
    if (is.list(x)) {
        x <- unclass(x)
        x <- lapply(x, unclass_recursive)
    }
    x
}
