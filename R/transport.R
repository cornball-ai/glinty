# The transport seam. Two implementations of one small interface sit
# behind REG$transport: base R sockets (the default, with all of the
# protocol code in this package behind it) and civetwebR, chosen when
# run_app() is given a host to bind or a certificate. The registry and
# the app layer call these operations; nothing else touches a socket or
# a CivetWeb connection id.
#
#   listen(port, host, tls_cert)  -> list(host, port) as bound
#   wait(handlers, timeout)       -> block up to timeout seconds, then
#                                    dispatch everything that arrived
#   ws_send(entry, text)          -> logical, FALSE when the write failed
#   ws_close(entry, code)         -> best-effort close frame
#   close_conn(entry)             -> release the connection
#   close()                       -> stop listening
#
# An entry is a registry environment (see conn_add()); its `con` is a
# socket connection for the base transport and a CivetWeb connection
# id for civetwebR.

#' The base R socket transport
#'
#' serverSocket() takes no bind address, so this listens on every
#' interface. HTTP parsing, the WebSocket handshake and framing all
#' happen in R, on the bytes each non-blocking connection has buffered.
#'
#' @return a transport list
#' @keywords internal
transport_base <- function() {
    list(
        name = "base",
        listen = function(port, host, tls_cert) {
            REG$srv <- serverSocket(as.integer(port))
            list(host = "0.0.0.0", port = as.integer(port))
        },
        wait = function(handlers, timeout) base_wait(handlers, timeout),
        ws_send = function(entry, text) base_write(entry, ws_text_frame(text)),
        ws_close = function(entry, code) base_write(entry, ws_close_frame(code)),
        close_conn = function(entry) {
            tryCatch(close(entry$con), error = function(e) NULL)
            invisible(NULL)
        },
        close = function() {
            if (!is.null(REG$srv)) {
                tryCatch(close(REG$srv), error = function(e) NULL)
                REG$srv <- NULL
            }
            invisible(NULL)
        }
    )
}

#' Write bytes to a base transport connection
#'
#' A failed write surfaces from R as a warning, which here means
#' FALSE; the caller decides whether that marks the connection dead.
#'
#' @param entry registry entry
#' @param bytes raw vector
#' @return logical success
#' @keywords internal
base_write <- function(entry, bytes) {
    ok <- TRUE
    tryCatch(
             withCallingHandlers(
                                 writeBin(bytes, entry$con),
                                 warning = function(w) {
        ok <<- FALSE
        invokeRestart("muffleWarning")
    }
        ),
             error = function(e) ok <<- FALSE
    )
    ok
}

#' One wait on the base transport
#'
#' Sleeps in socketSelect() for up to `timeout` seconds, accepts what
#' arrived on the listener, and feeds each readable connection's bytes
#' to its state machine.
#'
#' @param handlers the handler list
#' @param timeout numeric seconds
#' @return invisible(NULL)
#' @keywords internal
base_wait <- function(handlers, timeout) {
    srv <- REG$srv
    conn_keys <- names(REG$conns)
    socks <- c(list(srv),
               unname(lapply(REG$conns[conn_keys], function(e) e$con)))
    ready <- socketSelect(socks, write = FALSE, timeout = timeout)

    if (isTRUE(ready[1L])) {
        con <- tryCatch(
                        socketAccept(srv, blocking = FALSE, open = "r+b", timeout = 5),
                        error = function(e) NULL
        )
        if (!is.null(con)) {
            conn_add(con, "http_pending")
        }
    }

    readable <- conn_keys[ready[-1L]]
    for (key in readable) {
        entry <- REG$conns[[key]]
        if (is.null(entry)) {
            next
        }
        tryCatch({
            data <- drain_socket(entry$con)
            if (length(data) == 0L) {
                # readable + zero bytes == EOF; close now or the
                # connection stays "readable" forever and spins us
                conn_close(key, notify = TRUE, handlers = handlers)
            } else {
                entry$buf <- c(entry$buf, data)
                if (length(entry$buf) > MAX_CONN_BUF) {
                    conn_close(key, notify = TRUE, handlers = handlers,
                               code = 1009L)
                } else if (identical(entry$state, "http_pending")) {
                    handle_http_bytes(key, handlers)
                } else if (identical(entry$state, "http_body")) {
                    handle_http_body(key, handlers)
                } else {
                    handle_ws_bytes(key, handlers)
                }
            }
        }, error = function(e) {
            conn_close(key, notify = TRUE, handlers = handlers)
        })
    }
    invisible(NULL)
}

#' The civetwebR transport
#'
#' CivetWeb owns the sockets: it binds the given host, terminates TLS,
#' parses HTTP, performs the WebSocket handshake and frames. R sees
#' events from civetwebR::next_event() and answers them. What stays in
#' R is policy: the Origin check on an upgrade, the hello gate, and the
#' message-level rules the base transport applies (text only,
#' reassembly of fragments, the size cap).
#'
#' @return a transport list
#' @keywords internal
transport_civetweb <- function() {
    srv <- NULL
    list(
        name = "civetwebR",
        listen = function(port, host, tls_cert) {
            srv <<- civetwebR::start_server(
                port = as.integer(port), host = host, register = FALSE,
                ws_path = "/ws", keep_alive = FALSE,
                max_body_size = getOption("glinty.max_upload", 10485760L),
                tls_cert = tls_cert
            )
            REG$srv <- srv
            list(host = host, port = civetwebR::server_port(srv))
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
        # CivetWeb has already checked the upgrade itself; the policy
        # decision is the same one the base transport makes.
        req <- civet_request(ev)
        if (ws_origin_allowed(get_header(req, "origin"), get_header(req, "host"),
                              .globals$origins)) {
            conn_add(ev$id, "ws_pending", key = key)
            # Kept for the hello gate, as the base transport keeps it
            # (see handle_http_bytes()).
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
#' The same rules handle_ws_bytes() applies on the base transport:
#' binary frames fail the connection with 1003, a continuation without
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
#' The shape parse_http_head() produces: method, path, query and
#' headers with lower-cased names, plus the raw body when there is one.
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
        headers <- as.list(stats::setNames(vals[keep], keys[keep]))
    }
    list(status = status, headers = headers, body = body)
}
