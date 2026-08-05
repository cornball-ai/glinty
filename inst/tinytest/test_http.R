parse_http_head <- glinty:::parse_http_head
find_header_end <- glinty:::find_header_end
http_response_raw <- glinty:::http_response_raw
serve_static <- glinty:::serve_static

# --- find_header_end ---
buf <- charToRaw("GET / HTTP/1.1\r\nHost: x\r\n\r\nBODY")
pos <- find_header_end(buf)
expect_true(pos > 0L)
expect_equal(rawToChar(buf[seq_len(pos - 1L)]), "GET / HTTP/1.1\r\nHost: x")
expect_equal(find_header_end(charToRaw("GET / HTTP/1.1\r\nHost")), -1L)

# --- parse: method, path, query, lower-cased headers ---
req <- parse_http_head(charToRaw(
    "GET /search?q=hi&n=2 HTTP/1.1\r\nHost: localhost\r\nX-Custom: Yes"
))
expect_equal(req$method, "GET")
expect_equal(req$path, "/search")
expect_equal(req$query, "q=hi&n=2")
expect_equal(unname(req$headers[["host"]]), "localhost")
expect_equal(unname(req$headers[["x-custom"]]), "Yes")

# malformed head
expect_null(parse_http_head(charToRaw("GARBAGE")))

# --- response bytes ---
resp <- rawToChar(http_response_raw(200L, "text/plain", "hi"))
expect_true(startsWith(resp, "HTTP/1.1 200 OK\r\n"))
expect_true(grepl("Content-Length: 2\r\n", resp, fixed = TRUE))
expect_true(grepl("Connection: close\r\n", resp, fixed = TRUE))
expect_true(endsWith(resp, "\r\n\r\nhi"))

resp <- rawToChar(http_response_raw(426L, "text/plain", "x",
    extra_headers = c("Sec-WebSocket-Version" = "13")))
expect_true(grepl("Sec-WebSocket-Version: 13\r\n", resp, fixed = TRUE))

# --- static serving with traversal guard ---
dir <- tempfile("static")
dir.create(dir)
writeLines("body { color: red }", file.path(dir, "app.css"))

resp <- rawToChar(serve_static("app.css", dir))
expect_true(grepl("200 OK", resp))
expect_true(grepl("text/css", resp))
expect_true(grepl("color: red", resp))

expect_true(grepl("403", rawToChar(serve_static("../secret", dir))))
expect_true(grepl("404", rawToChar(serve_static("missing.css", dir))))
unlink(dir, recursive = TRUE)

# --- byte ranges: what makes a served video seekable ---
parse_range <- glinty:::parse_range
mime_type <- glinty:::mime_type
# Real media has nul bytes in it, so the headers get split off rather
# than rawToChar()'d with the body attached.
hdr <- function(resp) {
    pat <- charToRaw("\r\n\r\n")
    for (i in seq_len(length(resp) - 3L)) {
        if (all(resp[i:(i + 3L)] == pat)) {
            return(rawToChar(resp[seq_len(i - 1L)]))
        }
    }
    ""
}
body_of <- function(resp) {
    pat <- charToRaw("\r\n\r\n")
    for (i in seq_len(length(resp) - 3L)) {
        if (all(resp[i:(i + 3L)] == pat)) {
            return(resp[-seq_len(i + 3L)])
        }
    }
    raw(0)
}
vdir <- tempfile("vid")
dir.create(vdir)
writeBin(as.raw(0:255), file.path(vdir, "clip.mp4"))

# mp4 has to map to video/*, or a <video> element will not play it at all.
expect_equal(mime_type("mp4"), "video/mp4")
expect_equal(mime_type("m4v"), "video/mp4")
expect_equal(mime_type("mov"), "video/quicktime")
# webm stays audio: glinty writes audio-only webm and <audio> wants that.
expect_equal(mime_type("webm"), "audio/webm")

# A client that is not told it can seek will not try, so every response
# advertises it, including the plain 200.
whole <- serve_static("clip.mp4", vdir)
expect_true(grepl("HTTP/1.1 200 OK", hdr(whole), fixed = TRUE))
expect_true(grepl("Content-Type: video/mp4", hdr(whole), fixed = TRUE))
expect_true(grepl("Accept-Ranges: bytes", hdr(whole), fixed = TRUE))
expect_equal(body_of(whole), as.raw(0:255))

# bytes=from-to
r1 <- serve_static("clip.mp4", vdir, "bytes=10-19")
expect_true(grepl("HTTP/1.1 206 Partial Content", hdr(r1), fixed = TRUE))
expect_true(grepl("Content-Range: bytes 10-19/256", hdr(r1), fixed = TRUE))
expect_true(grepl("Content-Length: 10", hdr(r1), fixed = TRUE))
expect_equal(body_of(r1), as.raw(10:19))

# bytes=from- runs to the end, which is what a browser opens with.
r2 <- serve_static("clip.mp4", vdir, "bytes=250-")
expect_equal(body_of(r2), as.raw(250:255))
expect_true(grepl("Content-Range: bytes 250-255/256", hdr(r2), fixed = TRUE))
# bytes=-n is the last n bytes: how a player finds the moov atom.
r3 <- serve_static("clip.mp4", vdir, "bytes=-4")
expect_equal(body_of(r3), as.raw(252:255))
expect_true(grepl("Content-Range: bytes 252-255/256", hdr(r3), fixed = TRUE))
# An end past the file is clamped rather than refused.
r4 <- serve_static("clip.mp4", vdir, "bytes=254-9999")
expect_equal(body_of(r4), as.raw(254:255))
# A single byte is a legal range.
expect_equal(body_of(serve_static("clip.mp4", vdir, "bytes=0-0")), as.raw(0))

# Past the end entirely is a 416 that says how long the file really is.
r5 <- serve_static("clip.mp4", vdir, "bytes=999-1200")
expect_true(grepl("HTTP/1.1 416 Range Not Satisfiable", hdr(r5), fixed = TRUE))
expect_true(grepl("Content-Range: bytes */256", hdr(r5), fixed = TRUE))

# Anything unparsed falls back to the whole file: a complete response is
# always a valid answer to a range request, so a header we do not read
# costs a fallback rather than an error.
expect_null(parse_range("bytes=0-9,20-29", 256)) # multi-range
expect_null(parse_range("items=0-9", 256))
expect_null(parse_range("bytes=-", 256))
expect_null(parse_range("bytes=abc-def", 256))
expect_null(parse_range(NULL, 256))
expect_null(parse_range(NA_character_, 256))
expect_null(parse_range("", 256))
expect_true(grepl("HTTP/1.1 200 OK",
                  hdr(serve_static("clip.mp4", vdir, "bytes=0-9,20-29")),
                  fixed = TRUE))
# An empty file cannot satisfy any range.
expect_true(is.na(parse_range("bytes=0-9", 0)))
expect_true(is.na(parse_range("bytes=-4", 0)))
# The traversal and existence guards still come first, range or not.
expect_true(grepl("403", hdr(serve_static("../secret", vdir, "bytes=0-9")),
                  fixed = TRUE))
expect_true(grepl("404", hdr(serve_static("gone.mp4", vdir, "bytes=0-9")),
                  fixed = TRUE))
unlink(vdir, recursive = TRUE)
