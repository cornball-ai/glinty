ws_accept_key <- glinty:::ws_accept_key
ws_is_upgrade <- glinty:::ws_is_upgrade
ws_handshake_result <- glinty:::ws_handshake_result
parse_http_head <- glinty:::parse_http_head
header_has_token <- glinty:::header_has_token

# --- RFC 6455 sample key ---
expect_equal(
    ws_accept_key("dGhlIHNhbXBsZSBub25jZQ=="),
    "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
)

# --- token matching handles comma lists and case ---
expect_true(header_has_token("Upgrade", "upgrade"))
expect_true(header_has_token("keep-alive, Upgrade", "upgrade"))
expect_false(header_has_token("keep-alive", "upgrade"))
expect_false(header_has_token(NULL, "upgrade"))

req_txt <- paste0(
    "GET /ws HTTP/1.1\r\n",
    "Host: localhost:8080\r\n",
    "Upgrade: websocket\r\n",
    "Connection: keep-alive, Upgrade\r\n",
    "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n",
    "Sec-WebSocket-Version: 13"
)
req <- parse_http_head(charToRaw(req_txt))
expect_equal(req$method, "GET")
expect_equal(req$path, "/ws")
expect_true(ws_is_upgrade(req))

# --- successful handshake: 101 with the right accept ---
hs <- ws_handshake_result(req)
expect_true(hs$ok)
resp <- rawToChar(hs$response)
expect_true(startsWith(resp, "HTTP/1.1 101 Switching Protocols\r\n"))
expect_true(grepl("Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK\\+xOo=",
    resp))
expect_true(grepl("Upgrade: websocket", resp))

# --- wrong version: 426 with advertised version ---
req8 <- req
req8$headers[["sec-websocket-version"]] <- "8"
hs <- ws_handshake_result(req8)
expect_false(hs$ok)
resp <- rawToChar(hs$response)
expect_true(grepl("426", resp))
expect_true(grepl("Sec-WebSocket-Version: 13", resp))

# --- missing key: 400 ---
req_nokey <- req
req_nokey$headers <- req$headers[names(req$headers) !=
    "sec-websocket-key"]
hs <- ws_handshake_result(req_nokey)
expect_false(hs$ok)
expect_true(grepl("400", rawToChar(hs$response)))

# --- non-upgrade requests are not upgrades ---
plain <- parse_http_head(charToRaw(
    "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive"
))
expect_false(ws_is_upgrade(plain))

# --- origin: same-host default (#48) ---
# Browsers exempt WebSockets from the same-origin policy, so the
# handshake refuses pages this server did not serve. The comparison
# is Origin against Host, never against a hardcoded localhost.

hs_req <- function(origin = NULL, host = "localhost:8080") {
    lines <- c("GET /ws HTTP/1.1",
               if (!is.null(host)) paste0("Host: ", host),
               "Upgrade: websocket",
               "Connection: Upgrade",
               "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==",
               "Sec-WebSocket-Version: 13",
               if (!is.null(origin)) paste0("Origin: ", origin))
    parse_http_head(charToRaw(paste(lines, collapse = "\r\n")))
}

# absent Origin: a non-browser client, allowed
expect_true(ws_handshake_result(hs_req())$ok)
# the page this server served
expect_true(ws_handshake_result(hs_req("http://localhost:8080"))$ok)
# hosts compare case-insensitively
expect_true(ws_handshake_result(hs_req("http://LOCALHOST:8080"))$ok)
# implied ports match a portless Host, either scheme
expect_true(ws_handshake_result(
    hs_req("http://myapp.example", host = "myapp.example"))$ok)
expect_true(ws_handshake_result(
    hs_req("https://myapp.example", host = "myapp.example"))$ok)
# a tailnet name matches itself
expect_true(ws_handshake_result(
    hs_req("http://troy-g5.tail.ts.net:8080",
           host = "troy-g5.tail.ts.net:8080"))$ok)
# bracketed IPv6
expect_true(ws_handshake_result(
    hs_req("http://[::1]:8080", host = "[::1]:8080"))$ok)

# a different site: refused with 403
hs <- ws_handshake_result(hs_req("https://evil.example"))
expect_false(hs$ok)
expect_true(startsWith(rawToChar(hs$response), "HTTP/1.1 403 Forbidden"))
# a different port on the same host is a different origin
expect_false(ws_handshake_result(hs_req("http://localhost:9999"))$ok)
# implied origin ports (80, 443) against an explicit 8080
expect_false(ws_handshake_result(hs_req("http://localhost"))$ok)
expect_false(ws_handshake_result(hs_req("https://localhost"))$ok)
# nonstandard origin port against a portless Host
expect_false(ws_handshake_result(
    hs_req("http://myapp.example:8080", host = "myapp.example"))$ok)
# opaque origins ("null": sandboxed iframe, file://) refuse
expect_false(ws_handshake_result(hs_req("null"))$ok)
# an Origin with no Host to compare against refuses
expect_false(ws_handshake_result(
    hs_req("http://localhost:8080", host = NULL))$ok)

# --- origin: allowlist and "*" ---
allow <- "https://app.example.com"
expect_true(ws_handshake_result(
    hs_req("https://app.example.com"), origins = allow)$ok)
# default port stripped on both sides of the comparison
expect_true(ws_handshake_result(
    hs_req("https://app.example.com:443"), origins = allow)$ok)
expect_true(ws_handshake_result(
    hs_req("https://APP.example.com"),
    origins = "https://app.example.com:443")$ok)
# same-host stays allowed alongside an allowlist
expect_true(ws_handshake_result(
    hs_req("http://localhost:8080"), origins = allow)$ok)
expect_false(ws_handshake_result(
    hs_req("https://other.example.com"), origins = allow)$ok)
# "null" can be allowlisted, but only literally
expect_true(ws_handshake_result(hs_req("null"), origins = "null")$ok)
expect_false(ws_handshake_result(hs_req("null"), origins = allow)$ok)
# "*" disables the check
expect_true(ws_handshake_result(
    hs_req("https://evil.example"), origins = "*")$ok)

# --- origin: parsing helpers stay strict ---
split_host_port <- glinty:::split_host_port
normalize_origin <- glinty:::normalize_origin
expect_equal(split_host_port("Example.COM:8080"),
             list(host = "example.com", port = 8080L))
expect_equal(split_host_port("example.com")$port, NA_integer_)
expect_null(split_host_port("exa mple.com"))
expect_null(split_host_port("example.com/path"))
expect_equal(normalize_origin("HTTPS://App.Example.com:443"),
             "https://app.example.com")
expect_equal(normalize_origin("http://app.example.com:8080"),
             "http://app.example.com:8080")
expect_null(normalize_origin("null"))
