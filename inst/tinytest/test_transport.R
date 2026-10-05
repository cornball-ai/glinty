# The transport seam: the pure pieces that adapt civetwebR's events
# and glinty's responses, and the frame rules applied to civetwebR
# data frames, driven through a recording transport. No sockets and
# no civetwebR needed: the seam is a list of functions.

REG <- glinty:::REG
reg_reset <- glinty:::reg_reset
conn_add <- glinty:::conn_add
civet_frame <- glinty:::civet_frame
civet_request <- glinty:::civet_request
raw_response_parts <- glinty:::raw_response_parts
http_response_raw <- glinty:::http_response_raw

# --- raw_response_parts(): what http_response_raw() builds, split ---
resp <- http_response_raw(206L, "video/mp4", as.raw(1:5),
    c("Accept-Ranges" = "bytes", "Content-Range" = "bytes 0-4/10"))
parts <- raw_response_parts(resp)
expect_equal(parts$status, 206L)
expect_equal(parts$body, as.raw(1:5))
expect_equal(parts$headers[["Content-Type"]], "video/mp4")
expect_equal(parts$headers[["Accept-Ranges"]], "bytes")
expect_equal(parts$headers[["Content-Range"]], "bytes 0-4/10")
# civetwebR writes these two itself
expect_false("Content-Length" %in% names(parts$headers))
expect_false("Connection" %in% names(parts$headers))

# an empty body and a text body
parts <- raw_response_parts(http_response_raw(204L, "text/plain", ""))
expect_equal(parts$status, 204L)
expect_equal(parts$body, raw(0L))
parts <- raw_response_parts(http_response_raw(404L, "text/plain", "Not found"))
expect_equal(rawToChar(parts$body), "Not found")

# garbage is a 500, not an error on the event loop
parts <- raw_response_parts(charToRaw("not an http response"))
expect_equal(parts$status, 500L)

# --- civet_request(): header names lower-cased, body only when present ---
ev <- list(method = "GET", path = "/ws", query = "a=1",
           headers = c(Host = "localhost:8080", Origin = "http://localhost:8080",
                       "Sec-WebSocket-Key" = "x"),
           body = raw(0L))
req <- civet_request(ev)
expect_equal(req$method, "GET")
expect_equal(req$path, "/ws")
expect_equal(req$query, "a=1")
expect_equal(glinty:::get_header(req, "origin"), "http://localhost:8080")
expect_equal(glinty:::get_header(req, "sec-websocket-key"), "x")
expect_null(req$body)
ev$body <- as.raw(1:3)
expect_equal(civet_request(ev)$body, as.raw(1:3))

# --- civet_frame(): the frame rules, through a recording transport ---
reg_reset()
closes <- list()
REG$transport <- list(
    name = "fake",
    ws_send = function(entry, text) TRUE,
    ws_close = function(entry, code) {
        closes[[length(closes) + 1L]] <<- list(key = entry$session_id, code = code)
        TRUE
    },
    close_conn = function(entry) invisible(NULL),
    close = function() invisible(NULL)
)
delivered <- list()
closed_sids <- character(0L)
handlers <- list(
    on_message = function(sid, txt) delivered[[length(delivered) + 1L]] <<- txt,
    on_close = function(sid) closed_sids <<- c(closed_sids, sid)
)
open_conn <- function(sid) {
    key <- conn_add(7L, "ws_open", key = paste0("w", sid))
    entry <- REG$conns[[key]]
    entry$session_id <- sid
    REG$sessions[[sid]] <- key
    list(key = key, entry = entry)
}
frame <- function(body, opcode = 1L, fin = TRUE, binary = FALSE) {
    list(id = 7L, body = charToRaw(body), opcode = opcode, fin = fin,
         binary = binary)
}

# a whole text frame is delivered as one message
c1 <- open_conn("s1")
civet_frame(c1$key, c1$entry, frame('{"a":1}'), handlers)
expect_equal(delivered, list('{"a":1}'))

# a text frame then a continuation reassemble; the first carries
# opcode 1, the rest 0
delivered <- list()
civet_frame(c1$key, c1$entry, frame('{"a":', fin = FALSE), handlers)
expect_equal(length(delivered), 0L)
expect_equal(c1$entry$frag_opcode, glinty:::WS_TEXT)
civet_frame(c1$key, c1$entry, frame('2}', opcode = 0L, fin = TRUE), handlers)
expect_equal(delivered, list('{"a":2}'))
expect_null(c1$entry$frag_opcode)
expect_equal(length(closes), 0L)

# a binary frame fails the connection with 1003 and tears the session down
civet_frame(c1$key, c1$entry, frame("x", opcode = 2L, binary = TRUE), handlers)
expect_equal(closes[[1L]]$code, 1003L)
expect_equal(closed_sids, "s1")
expect_null(REG$conns[[c1$key]])

# a continuation with no message open is a protocol error (1002)
c2 <- open_conn("s2")
civet_frame(c2$key, c2$entry, frame("x", opcode = 0L), handlers)
expect_equal(closes[[2L]]$code, 1002L)

# a new text frame while a message is open is a protocol error too
c3 <- open_conn("s3")
civet_frame(c3$key, c3$entry, frame("a", fin = FALSE), handlers)
civet_frame(c3$key, c3$entry, frame("b", opcode = 1L, fin = TRUE), handlers)
expect_equal(closes[[3L]]$code, 1002L)

# an over-sized reassembly is 1009
c4 <- open_conn("s4")
old <- options(glinty.max_message = 8L)
civet_frame(c4$key, c4$entry, frame("12345", fin = FALSE), handlers)
civet_frame(c4$key, c4$entry, frame("6789", opcode = 0L, fin = TRUE), handlers)
options(old)
expect_equal(closes[[4L]]$code, 1009L)

# invalid UTF-8 in a complete message is 1007 (ws_deliver's rule)
c5 <- open_conn("s5")
bad <- list(id = 7L, body = as.raw(c(0xff, 0xfe)), opcode = 1L, fin = TRUE,
            binary = FALSE)
civet_frame(c5$key, c5$entry, bad, handlers)
expect_equal(closes[[5L]]$code, 1007L)

reg_reset()
