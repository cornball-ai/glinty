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
