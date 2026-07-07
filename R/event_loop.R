# The single-threaded select loop. Every accepted connection is
# non-blocking with a per-connection byte buffer, so a slow or
# malicious client parks bytes in its own buffer and can never stall
# other sessions.

MAX_HTTP_HEAD <- 16384L
MAX_CONN_BUF <- 16777216L

#' Run the HTTP + WebSocket server loop
#'
#' Blocks until interrupted. Handlers connect the transport to the
#' app layer: on_request(req) returns a raw HTTP response (or NULL
#' for 404), on_open(session_id) / on_message(session_id, txt) /
#' on_close(session_id) manage sessions. Each loop tick fires due
#' timers, flushes reactions, and drains every session's outgoing
#' queue before sleeping in socketSelect (timeout capped at max_tick
#' seconds so Ctrl-C stays responsive).
#'
#' @param port integer TCP port
#' @param handlers list of on_request, on_open, on_message, on_close
#' @param max_tick numeric maximum select timeout in seconds
#' @return invisible(NULL); runs until interrupt
#' @keywords internal
run_ws_server <- function(port, handlers, max_tick = 1) {
    reg_reset()
    srv <- serverSocket(as.integer(port))
    REG$srv <- srv
    on.exit(loop_shutdown(handlers), add = TRUE)

    tryCatch(
        repeat {
            loop_tick(srv, handlers, max_tick)
        },
             interrupt = function(e) message("\nglinty server stopped.")
    )
    invisible(NULL)
}

#' One iteration of the event loop
#'
#' @param srv the server socket
#' @param handlers the handler list
#' @param max_tick numeric maximum select timeout in seconds
#' @return invisible(NULL)
#' @keywords internal
loop_tick <- function(srv, handlers, max_tick) {
    # Deferred closes from failed writes, then timers, then the
    # reactive flush, then push everything queued out the door.
    for (key in REG$dead) {
        conn_close(key, notify = TRUE, handlers = handlers)
    }
    run_due_timers()
    flush_reactions()
    drain_all_sessions()

    tmo <- next_timer_deadline()
    if (is.null(tmo)) {
        tmo <- max_tick
    } else {
        tmo <- min(max_tick, max(tmo, 0))
    }

    conn_keys <- names(REG$conns)
    socks <- c(list(srv),
               unname(lapply(REG$conns[conn_keys], function(e) e$con)))
    ready <- socketSelect(socks, write = FALSE, timeout = tmo)

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

#' Read everything currently buffered on a non-blocking socket
#'
#' @param con a socket connection
#' @return raw vector (length 0 means EOF if select said readable)
#' @keywords internal
drain_socket <- function(con) {
    out <- raw(0L)
    repeat {
        chunk <- readBin(con, "raw", 65536L)
        out <- c(out, chunk)
        if (length(chunk) < 65536L) {
            break
        }
    }
    out
}

#' Advance an http_pending connection
#'
#' Waits for a complete head, then routes: WebSocket upgrades promote
#' the connection and open a session; anything else gets a plain HTTP
#' response and Connection: close. GET only in v0.1 -- the WebSocket
#' carries the app after page load.
#'
#' @param key character connection key
#' @param handlers the handler list
#' @return invisible(NULL)
#' @keywords internal
handle_http_bytes <- function(key, handlers) {
    entry <- REG$conns[[key]]
    pos <- find_header_end(entry$buf)
    if (pos < 0L) {
        if (length(entry$buf) > MAX_HTTP_HEAD) {
            tryCatch(suppressWarnings(writeBin(
                        http_response_raw(400L, "text/plain", "Bad Request"),
                        entry$con
                    )), error = function(e) NULL)
            conn_close(key, notify = FALSE, handlers = handlers)
        }
        return(invisible(NULL))
    }

    if (pos > 1L) {
        head_raw <- entry$buf[seq_len(pos - 1L)]
    } else {
        head_raw <- raw(0L)
    }
    # keep any bytes past the head: a request body may ride along
    entry$buf <- if (length(entry$buf) > pos + 3L) {
        entry$buf[(pos + 4L):length(entry$buf)]
    } else {
        raw(0L)
    }
    req <- parse_http_head(head_raw)
    if (is.null(req)) {
        tryCatch(suppressWarnings(writeBin(
                    http_response_raw(400L, "text/plain", "Bad Request"),
                    entry$con
                )), error = function(e) NULL)
        conn_close(key, notify = FALSE, handlers = handlers)
        return(invisible(NULL))
    }

    if (identical(req$method, "GET") && identical(req$path, "/ws") &&
        ws_is_upgrade(req)) {
        hs <- ws_handshake_result(req)
        write_ok <- tryCatch({
            suppressWarnings(writeBin(hs$response, entry$con))
            TRUE
        }, error = function(e) FALSE)
        if (hs$ok && write_ok) {
            entry$state <- "ws_open"
            sid <- new_session_id()
            entry$session_id <- sid
            REG$sessions[[sid]] <- key
            if (!is.null(handlers$on_open)) {
                handlers$on_open(sid)
            }
        } else {
            conn_close(key, notify = FALSE, handlers = handlers)
        }
        return(invisible(NULL))
    }

    # Requests with a body (uploads): buffer until Content-Length
    # bytes have arrived, then route with the raw body attached.
    clen <- suppressWarnings(as.integer(get_header(req, "content-length")))
    if (!identical(req$method, "GET") && length(clen) == 1L &&
        !is.na(clen) && clen > 0L) {
        if (clen > getOption("glinty.max_upload", 10485760L)) {
            tryCatch(suppressWarnings(writeBin(
                        http_response_raw(413L, "text/plain",
                            "Payload Too Large"),
                        entry$con
                    )), error = function(e) NULL)
            conn_close(key, notify = FALSE, handlers = handlers)
            return(invisible(NULL))
        }
        entry$state <- "http_body"
        entry$pending_req <- req
        entry$body_needed <- clen
        handle_http_body(key, handlers)
        return(invisible(NULL))
    }

    respond_and_close(key, req, handlers)
}

#' Advance an http_body connection
#'
#' Waits until the buffered bytes cover the declared Content-Length,
#' then routes the request with its raw body (never coerced to
#' character -- uploads are binary).
#'
#' @param key character connection key
#' @param handlers the handler list
#' @return invisible(NULL)
#' @keywords internal
handle_http_body <- function(key, handlers) {
    entry <- REG$conns[[key]]
    if (length(entry$buf) < entry$body_needed) {
        return(invisible(NULL))
    }
    req <- entry$pending_req
    req$body <- entry$buf[seq_len(entry$body_needed)]
    entry$buf <- raw(0L)
    entry$pending_req <- NULL
    respond_and_close(key, req, handlers)
}

#' Route a complete request and close the connection
#'
#' @param key character connection key
#' @param req parsed request (with body when present)
#' @param handlers the handler list
#' @return invisible(NULL)
#' @keywords internal
respond_and_close <- function(key, req, handlers) {
    entry <- REG$conns[[key]]
    resp <- NULL
    if (!is.null(handlers$on_request)) {
        resp <- tryCatch(handlers$on_request(req), error = function(e) {
            http_response_raw(500L, "text/plain", conditionMessage(e))
        })
    }
    if (is.null(resp)) {
        resp <- http_response_raw(404L, "text/plain", "Not found")
    }
    tryCatch(suppressWarnings(writeBin(resp, entry$con)),
             error = function(e) NULL)
    conn_close(key, notify = FALSE, handlers = handlers)
    invisible(NULL)
}

#' Advance a ws_open connection
#'
#' Decodes and dispatches EVERY complete frame in the buffer (a
#' single readable event can deliver several), leaving partial bytes
#' for the next wake. Client frames must be masked. Fragmented text
#' is reassembled; control frames may interleave.
#'
#' @param key character connection key
#' @param handlers the handler list
#' @return invisible(NULL)
#' @keywords internal
handle_ws_bytes <- function(key, handlers) {
    max_message <- getOption("glinty.max_message", 8388608L)
    repeat {
        entry <- REG$conns[[key]]
        if (is.null(entry)) {
            return(invisible(NULL))
        }
        frame <- ws_decode_frame(entry$buf)
        if (is.null(frame)) {
            return(invisible(NULL))
        }
        if (isTRUE(frame$error)) {
            ws_fail(key, frame$code, handlers)
            return(invisible(NULL))
        }
        entry$buf <- frame$rest

        if (!frame$masked) {
            ws_fail(key, 1002L, handlers)
            return(invisible(NULL))
        }

        op <- frame$opcode
        if (op == WS_TEXT || op == WS_BINARY) {
            if (op == WS_BINARY) {
                ws_fail(key, 1003L, handlers)
                return(invisible(NULL))
            }
            if (!is.null(entry$frag_opcode)) {
                # new data frame while a fragmented message is open
                ws_fail(key, 1002L, handlers)
                return(invisible(NULL))
            }
            if (frame$fin) {
                if (!ws_deliver(key, frame$payload, handlers)) {
                    return(invisible(NULL))
                }
            } else {
                entry$frag_opcode <- op
                entry$frag_buf <- frame$payload
            }
        } else if (op == WS_CONT) {
            if (is.null(entry$frag_opcode)) {
                ws_fail(key, 1002L, handlers)
                return(invisible(NULL))
            }
            entry$frag_buf <- c(entry$frag_buf, frame$payload)
            if (length(entry$frag_buf) > max_message) {
                ws_fail(key, 1009L, handlers)
                return(invisible(NULL))
            }
            if (frame$fin) {
                payload <- entry$frag_buf
                entry$frag_opcode <- NULL
                entry$frag_buf <- raw(0L)
                if (!ws_deliver(key, payload, handlers)) {
                    return(invisible(NULL))
                }
            }
        } else if (op == WS_CLOSE) {
            conn_close(key, notify = TRUE, handlers = handlers)
            return(invisible(NULL))
        } else if (op == WS_PING) {
            tryCatch(
                     suppressWarnings(writeBin(ws_pong_frame(frame$payload),
                        entry$con)),
                     error = function(e) mark_dead(key)
            )
        } else if (op == WS_PONG) {
            # ignore
        } else {
            ws_fail(key, 1002L, handlers)
            return(invisible(NULL))
        }
    }
}

#' Deliver a complete text payload to the app layer
#'
#' @param key character connection key
#' @param payload raw UTF-8 bytes
#' @param handlers the handler list
#' @return logical FALSE if the connection was failed
#' @keywords internal
ws_deliver <- function(key, payload, handlers) {
    txt <- tryCatch(rawToChar(payload), error = function(e) NULL)
    if (is.null(txt) || length(validUTF8(txt)) == 0L || !validUTF8(txt)) {
        ws_fail(key, 1007L, handlers)
        return(FALSE)
    }
    Encoding(txt) <- "UTF-8"
    entry <- REG$conns[[key]]
    if (!is.null(handlers$on_message) && !is.null(entry$session_id)) {
        handlers$on_message(entry$session_id, txt)
    }
    TRUE
}

#' Fail a WebSocket connection
#'
#' Best-effort close frame with the protocol error code, then close
#' and notify.
#'
#' @param key character connection key
#' @param code integer close code
#' @param handlers the handler list
#' @return invisible(NULL)
#' @keywords internal
ws_fail <- function(key, code, handlers) {
    conn_close(key, notify = TRUE, handlers = handlers, code = code)
    invisible(NULL)
}

#' Drain every live session's outgoing queue
#'
#' @return invisible(NULL)
#' @keywords internal
drain_all_sessions <- function() {
    for (sid in ls(.globals$sessions)) {
        s <- .globals$sessions[[sid]]
        if (!is.null(s)) {
            drain_session(s)
        }
    }
    invisible(NULL)
}

#' Shut the server down
#'
#' Closes every connection (1001 going away, with session teardown)
#' and the listening socket.
#'
#' @param handlers the handler list
#' @return invisible(NULL)
#' @keywords internal
loop_shutdown <- function(handlers) {
    for (key in names(REG$conns)) {
        conn_close(key, notify = TRUE, handlers = handlers, code = 1001L)
    }
    if (!is.null(REG$srv)) {
        tryCatch(close(REG$srv), error = function(e) NULL)
        REG$srv <- NULL
    }
    invisible(NULL)
}
