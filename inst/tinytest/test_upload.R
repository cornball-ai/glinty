# multipart parsing, query parsing, and the upload route

extract_boundary <- glinty:::extract_boundary
parse_multipart <- glinty:::parse_multipart
parse_query <- glinty:::parse_query
handle_upload <- glinty:::handle_upload

# --- boundary extraction ---
expect_equal(
    extract_boundary("multipart/form-data; boundary=----WebKitABC123"),
    "----WebKitABC123"
)
expect_equal(
    extract_boundary('multipart/form-data; boundary="quoted-b"; charset=x'),
    "quoted-b"
)
expect_null(extract_boundary("application/json"))
expect_null(extract_boundary(NULL))

# --- query parsing ---
q <- parse_query("session=abc123&id=my%20input&flag")
expect_equal(unname(q["session"]), "abc123")
expect_equal(unname(q["id"]), "my input")
expect_equal(unname(q["flag"]), "")
expect_equal(length(parse_query("")), 0L)
expect_equal(unname(parse_query("a=1+2")["a"]), "1 2")

# --- multipart: binary file part + repeated text fields ---
# binary payload deliberately contains CRLF and boundary-ish bytes
bin <- as.raw(c(0:255, 13, 10, 45, 45, 13, 10))
b <- "xyzBOUNDARYxyz"
crlf <- "\r\n"
part <- function(headers, body_raw) {
    c(charToRaw(paste0("--", b, crlf, headers, crlf, crlf)),
      body_raw, charToRaw(crlf))
}
body <- c(
    part('Content-Disposition: form-data; name="file"; filename="dat a.bin"',
        bin),
    part('Content-Disposition: form-data; name="tag"', charToRaw("one")),
    part('Content-Disposition: form-data; name="tag"', charToRaw("two")),
    charToRaw(paste0("--", b, "--", crlf))
)

parts <- parse_multipart(body, b)
expect_equal(sort(names(parts)), c("file", "tag"))
expect_equal(length(parts$file), 1L)
expect_identical(parts$file[[1L]]$value, bin)
expect_equal(parts$file[[1L]]$filename, "dat a.bin")
# repeated fields stay separate parts
expect_equal(length(parts$tag), 2L)
expect_equal(rawToChar(parts$tag[[1L]]$value), "one")
expect_equal(rawToChar(parts$tag[[2L]]$value), "two")
expect_true(is.na(parts$tag[[1L]]$filename))

# empty body / missing boundary
expect_equal(parse_multipart(raw(0L), b), list())
expect_equal(parse_multipart(charToRaw("junk"), b), list())

# --- upload route wired to a session ---
.g <- getFromNamespace(".globals", "glinty")
.g$current_context <- NULL
.g$pending_flush <- list()
.g$current_session <- NULL

s <- glinty:::new_session("up1")
seen <- NULL
observe_event(s$input$f, function(v) seen <<- v)

req <- list(
    method = "POST", path = "/upload",
    query = paste0("session=up1&id=f"),
    headers = c("content-type" = paste0(
        "multipart/form-data; boundary=", b)),
    body = body
)
resp <- rawToChar(handle_upload(req))
expect_true(grepl("200 OK", resp))
expect_true(grepl('"ok":true', resp))
flush_reactions()

expect_true(is.data.frame(seen))
expect_equal(nrow(seen), 1L)
expect_equal(seen$name, "dat a.bin")
expect_equal(seen$size, length(bin))
expect_true(file.exists(seen$datapath))
expect_identical(readBin(seen$datapath, "raw", seen$size), bin)

# upload dir is removed when the session ends
updir <- dirname(seen$datapath)
expect_true(dir.exists(updir))
glinty:::session_end(s)
expect_false(dir.exists(updir))

# --- error paths ---
expect_true(grepl("404", rawToChar(handle_upload(list(
    method = "POST", path = "/upload", query = "session=ghost&id=f",
    headers = c("content-type" = "multipart/form-data; boundary=x"),
    body = raw(0L)
)))))
expect_true(grepl("400", rawToChar(handle_upload(list(
    method = "POST", path = "/upload", query = "",
    headers = character(0L), body = raw(0L)
)))))
s2 <- glinty:::new_session("up2")
expect_true(grepl("400", rawToChar(handle_upload(list(
    method = "POST", path = "/upload", query = "session=up2&id=f",
    headers = c("content-type" = "application/json"),
    body = charToRaw("{}")
)))))
glinty:::session_end(s2)
