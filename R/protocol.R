#' Create an update message
#'
#' The DOM patch used by all outputs: set one property on the element
#' with the given id.
#'
#' @param id character element ID
#' @param property character DOM property to update
#' @param value new value
#' @return character JSON string
#' @keywords internal
update_msg <- function(id, property, value) {
    as.character(jsonlite::toJSON(
                                  list(type = "update", id = id, property = property, value = value),
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
update_input_msg <- function(id, fields) {
    msg <- c(list(type = "update_input", id = id), fields)
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
        if (is.character(msg$id)) {
            handle_input(session, msg$id, normalize_value(msg$value))
        }
    } else if (identical(msg$type, "event")) {
        if (is.character(msg$id)) {
            handle_event(session, msg$id)
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
