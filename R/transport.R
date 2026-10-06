# The transport: civetwebR. CivetWeb owns the sockets. It binds the
# address, terminates TLS, parses HTTP, performs the WebSocket
# handshake and frames; R sees events from civetwebR::next_event()
# and answers them. What stays in R is policy: the Origin check on an
# upgrade (R/origin.R), the hello gate, and the message-level rules
# (text only, reassembly of fragments, the size cap).
#
# The seam is a list of six operations behind REG$transport, so a
# second transport can sit beside this one. The registry and the app
# layer call these; nothing else touches a CivetWeb connection id.
#
#   listen(port, host, tls_cert)  -> list(host, port) as bound
#   wait(handlers, timeout)       -> block up to timeout seconds, then
#                                    dispatch everything that arrived
#   ws_send(entry, text)          -> logical, FALSE when the write failed
#   ws_close(entry, code)         -> best-effort close frame
#   close_conn(entry)             -> release the connection
#   close()                       -> stop listening
#
# An entry is a registry environment (see conn_add()); its `con` is
# the CivetWeb connection id.

# The opcode of a text frame: what civet_frame() records while a
# fragmented message is open.
WS_TEXT <- 1L

#' The civetwebR transport
#'
#' `host = NULL` binds every interface, which is what base R's
#' serverSocket() always did and what the startup message warns
#' about; an address binds that one.
#'
#' @return a transport list
#' @keywords internal
transport_civetweb <- function() {
    srv <- NULL
    list(
        name = "civetwebR",
        listen = function(port, host, tls_cert) {
            bind <- if (is.null(host)) "0.0.0.0" else host
            srv <<- civetwebR::start_server(
                port = as.integer(port), host = bind, register = FALSE,
                ws_path = "/ws", keep_alive = FALSE,
                max_body_size = getOption("glinty.max_upload", 10485760L),
                tls_cert = tls_cert
            )
            REG$srv <- srv
            list(host = bind, port = civetwebR::server_port(srv))
        },
        wait = function(handlers, timeout) {
            ev <- civetwebR::next_event(as.integer(round(timeout * 1000)), srv)
            while (!is.null(ev)) {
                civet_dispatch(ev, handlers, srv)
                ev <- civetwebR::next_event(0L, srv)
            }
            invisible(NULL)
        },
        ws_send = function(entry, text) {
            isTRUE(civetwebR::ws_send(entry$con, text, srv))
        },
        ws_close = function(entry, code) {
            isTRUE(civetwebR::ws_close(entry$con, as.integer(code), srv))
        },
        # CivetWeb closes the socket itself once the close frame above
        # is answered, or when its read loop ends; nothing to release.
        close_conn = function(entry) invisible(NULL),
        close = function() {
            if (!is.null(srv)) {
                tryCatch(civetwebR::stop_server(srv), error = function(e) NULL)
                srv <<- NULL
                REG$srv <- NULL
            }
            invisible(NULL)
        }
    )
}

#' Dispatch one civetwebR event
#'
#' @param ev a cw_request from civetwebR::next_event()
#' @param handlers the handler list
#' @param srv the civetwebR server handle
#' @return invisible(NULL)
#' @keywords internal
civet_dispatch <- function(ev, handlers, srv) {
    key <- sprintf("w%d", ev$id)
    switch(ev$event,
           request = {
        resp <- NULL
        if (isTRUE(ev$body_too_large)) {
            resp <- http_response_raw(413L, "text/plain", "Payload Too Large")
        } else if (!is.null(handlers$on_request)) {
            resp <- tryCatch(handlers$on_request(civet_request(ev)),
                             error = function(e) {
                http_response_raw(500L, "text/plain", conditionMessage(e))
            })
        }
        if (is.null(resp)) {
            resp <- http_response_raw(404L, "text/plain", "Not found")
        }
        civetwebR::send_response(ev$id, raw_response_parts(resp), srv)
    },
           ws_connect = {
        # CivetWeb has checked the upgrade itself; the policy decision
        # is glinty's, before the handshake is answered.
        req <- civet_request(ev)
        if (ws_origin_allowed(get_header(req, "origin"), get_header(req, "host"),
                              .globals$origins)) {
            conn_add(ev$id, "ws_pending", key = key)
            # The parsed head survives on the entry (headers included)
            # so the hello gate can hand it to a verifier: an HttpOnly
            # session cookie rides the upgrade request, never the
            # hello frame.
            REG$conns[[key]]$upgrade_req <- req
            civetwebR::send_response(ev$id, TRUE, srv)
        } else {
            civetwebR::send_response(ev$id, list(status = 403L), srv)
        }
    },
           ws_open = {
        entry <- REG$conns[[key]]
        if (is.null(entry)) {
            civetwebR::ws_close(ev$id, 1001L, srv)
            return(invisible(NULL))
        }
        entry$state <- "ws_open"
        sid <- new_session_id()
        entry$session_id <- sid
        REG$sessions[[sid]] <- key
        if (!is.null(handlers$on_open)) {
            handlers$on_open(sid)
        }
    },
           ws_message = {
        entry <- REG$conns[[key]]
        if (!is.null(entry)) {
            civet_frame(key, entry, ev, handlers)
        }
    },
           ws_close = {
        conn_close(key, notify = TRUE, handlers = handlers)
    })
    invisible(NULL)
}

#' Apply the message rules to one civetwebR data frame
#'
#' Binary frames fail the connection with 1003, a continuation without
#' an open message or a new message inside one with 1002, an
#' over-sized message with 1009; a complete text message is delivered
#' through ws_deliver(), which checks the UTF-8.
#'
#' @param key character connection key
#' @param entry registry entry
#' @param ev the ws_message event
#' @param handlers the handler list
#' @return invisible(NULL)
#' @keywords internal
civet_frame <- function(key, entry, ev, handlers) {
    max_message <- getOption("glinty.max_message", 8388608L)
    if (isTRUE(ev$binary)) {
        ws_fail(key, 1003L, handlers)
        return(invisible(NULL))
    }
    if (identical(ev$opcode, 0L)) {
        if (is.null(entry$frag_opcode)) {
            ws_fail(key, 1002L, handlers)
            return(invisible(NULL))
        }
        entry$frag_buf <- c(entry$frag_buf, ev$body)
        if (length(entry$frag_buf) > max_message) {
            ws_fail(key, 1009L, handlers)
            return(invisible(NULL))
        }
        if (isTRUE(ev$fin)) {
            payload <- entry$frag_buf
            entry$frag_opcode <- NULL
            entry$frag_buf <- raw(0L)
            ws_deliver(key, payload, handlers)
        }
        return(invisible(NULL))
    }
    if (!is.null(entry$frag_opcode)) {
        ws_fail(key, 1002L, handlers)
        return(invisible(NULL))
    }
    if (isTRUE(ev$fin)) {
        ws_deliver(key, ev$body, handlers)
    } else {
        entry$frag_opcode <- WS_TEXT
        entry$frag_buf <- ev$body
    }
    invisible(NULL)
}

#' A civetwebR event as a glinty request
#'
#' The shape the router reads: method, path, query and headers with
#' lower-cased names, plus the raw body when there is one.
#'
#' @param ev a cw_request
#' @return list(method, path, query, headers[, body])
#' @keywords internal
civet_request <- function(ev) {
    h <- ev$headers
    names(h) <- tolower(names(h))
    req <- list(method = ev$method, path = ev$path, query = ev$query,
                headers = h)
    if (length(ev$body) > 0L) {
        req$body <- ev$body
    }
    req
}

#' Split a raw HTTP response into its parts
#'
#' The app layer builds complete responses with http_response_raw();
#' civetwebR wants status, headers and body separately and writes
#' Content-Length and Connection itself, so those two are dropped.
#'
#' @param resp raw bytes of a full response
#' @return list(status, headers, body)
#' @keywords internal
raw_response_parts <- function(resp) {
    pos <- find_header_end(resp)
    if (pos < 1L) {
        return(list(status = 500L, headers = list(), body = raw(0L)))
    }
    head <- if (pos > 1L) rawToChar(resp[seq_len(pos - 1L)]) else ""
    body <- if (length(resp) > pos + 3L) {
        resp[(pos + 4L):length(resp)]
    } else {
        raw(0L)
    }
    lines <- strsplit(head, "\r\n", fixed = TRUE)[[1L]]
    status <- suppressWarnings(as.integer(strsplit(lines[1L], " ", fixed = TRUE)[[1L]][2L]))
    if (is.na(status)) {
        status <- 500L
    }
    headers <- list()
    if (length(lines) > 1L) {
        hl <- lines[-1L]
        hl <- hl[grepl(":", hl, fixed = TRUE)]
        keys <- sub(":.*$", "", hl)
        vals <- trimws(sub("^[^:]*:", "", hl))
        keep <- !tolower(keys) %in% c("content-length", "connection")
        vals <- vals[keep]
        names(vals) <- keys[keep]
        headers <- as.list(vals)
    }
    list(status = status, headers = headers, body = body)
}
