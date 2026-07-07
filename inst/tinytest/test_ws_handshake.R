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
