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

#' Create the session config message
#'
#' The first and only greeting a client receives after the WebSocket
#' opens.
#'
#' @param session_id character session ID
#' @return character JSON string
#' @keywords internal
config_msg <- function(session_id, resumed = NULL) {
    msg <- list(type = "config", session_id = session_id, protocol = 2L)
    if (!is.null(resumed)) {
        msg$resumed <- resumed
    }
    as.character(jsonlite::toJSON(msg, auto_unbox = TRUE))
}

#' Dispatch one client message to a session
#'
#' Parses the JSON text frame and routes by type: init seeds the
#' input environment with the client's harvested DOM values, input
#' applies a single input change, click bumps a click counter.
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
    if (identical(msg$type, "init")) {
        for (id in names(msg$inputs)) {
            handle_input(session, id, normalize_value(msg$inputs[[id]]))
        }
    } else if (identical(msg$type, "input")) {
        if (is.character(msg$id)) {
            handle_input(session, msg$id, normalize_value(msg$value))
        }
    } else if (identical(msg$type, "click")) {
        if (is.character(msg$id)) {
            handle_click(session, msg$id)
        }
    } else {
        session$send(error_msg(NULL,
                               paste0("unknown message type: ", msg$type)))
    }
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
