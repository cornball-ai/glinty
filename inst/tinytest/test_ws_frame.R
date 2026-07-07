ws_decode_frame <- glinty:::ws_decode_frame
ws_encode_frame <- glinty:::ws_encode_frame
ws_text_frame <- glinty:::ws_text_frame
ws_close_frame <- glinty:::ws_close_frame
ws_pong_frame <- glinty:::ws_pong_frame

# --- RFC 6455 5.7: unmasked "Hello" is 81 05 48 65 6c 6c 6f ---
hello_unmasked <- as.raw(c(0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f))
expect_identical(ws_text_frame("Hello"), hello_unmasked)

f <- ws_decode_frame(hello_unmasked)
expect_true(f$fin)
expect_equal(f$opcode, 1L)
expect_false(f$masked)
expect_equal(rawToChar(f$payload), "Hello")
expect_equal(length(f$rest), 0L)

# --- RFC 6455 5.7: masked "Hello" with key 37 fa 21 3d ---
hello_masked <- as.raw(c(0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d,
                         0x7f, 0x9f, 0x4d, 0x51, 0x58))
f <- ws_decode_frame(hello_masked)
expect_true(f$masked)
expect_equal(rawToChar(f$payload), "Hello")

# encoding with the same fixed key reproduces the RFC bytes
key <- as.raw(c(0x37, 0xfa, 0x21, 0x3d))
expect_identical(ws_text_frame("Hello", mask = TRUE, key = key),
    hello_masked)

# --- incremental feed: NULL until the last byte arrives ---
for (i in seq_len(length(hello_masked) - 1L)) {
    expect_null(ws_decode_frame(hello_masked[seq_len(i)]))
}
expect_false(is.null(ws_decode_frame(hello_masked)))

# --- two frames in one buffer: rest carries the second ---
two <- c(hello_unmasked, ws_text_frame("Bye"))
f1 <- ws_decode_frame(two)
expect_equal(rawToChar(f1$payload), "Hello")
f2 <- ws_decode_frame(f1$rest)
expect_equal(rawToChar(f2$payload), "Bye")
expect_equal(length(f2$rest), 0L)

# --- length forms at the boundaries round-trip ---
for (n in c(0L, 125L, 126L, 65535L, 65536L)) {
    payload <- as.raw(rep(0x61, n))
    enc <- ws_encode_frame(1L, payload)
    dec <- ws_decode_frame(enc, max_payload = 70000L)
    expect_equal(length(dec$payload), n, info = paste("len", n))
    # header sizes: 2 (<=125), 4 (16-bit), 10 (64-bit)
    hdr <- length(enc) - n
    expect_equal(hdr, if (n <= 125L) 2L else if (n <= 65535L) 4L else 10L,
        info = paste("hdr", n))
}

# --- masked round-trip with random key ---
payload <- charToRaw('{"type":"input","id":"x","value":"y"}')
enc <- ws_encode_frame(1L, payload, mask = TRUE)
dec <- ws_decode_frame(enc)
expect_true(dec$masked)
expect_identical(dec$payload, payload)

# --- RSV bits rejected ---
bad <- hello_unmasked
bad[1L] <- as.raw(0xC1)
err <- ws_decode_frame(bad)
expect_true(isTRUE(err$error))
expect_equal(err$code, 1002L)

# --- 64-bit length with nonzero high word rejected ---
huge <- as.raw(c(0x81, 0x7F, 0x00, 0x00, 0x00, 0x01, 0, 0, 0, 0))
err <- ws_decode_frame(huge)
expect_true(isTRUE(err$error))
expect_equal(err$code, 1009L)

# --- payload over max_payload rejected ---
big <- ws_encode_frame(1L, as.raw(rep(0x61, 200L)))
err <- ws_decode_frame(big, max_payload = 100L)
expect_true(isTRUE(err$error))
expect_equal(err$code, 1009L)

# --- close frame carries a big-endian code ---
cf <- ws_close_frame(1002L, "nope")
dec <- ws_decode_frame(cf)
expect_equal(dec$opcode, 8L)
code <- as.integer(dec$payload[1L]) * 256L + as.integer(dec$payload[2L])
expect_equal(code, 1002L)
expect_equal(rawToChar(dec$payload[-(1:2)]), "nope")

# --- pong echoes payload ---
pg <- ws_pong_frame(charToRaw("ping-data"))
dec <- ws_decode_frame(pg)
expect_equal(dec$opcode, 10L)
expect_equal(rawToChar(dec$payload), "ping-data")

# --- fragmented text: FIN off then continuation ---
frag1 <- ws_encode_frame(1L, charToRaw("Hel"), fin = FALSE)
frag2 <- ws_encode_frame(0L, charToRaw("lo"), fin = TRUE)
d1 <- ws_decode_frame(frag1)
expect_false(d1$fin)
expect_equal(d1$opcode, 1L)
d2 <- ws_decode_frame(frag2)
expect_true(d2$fin)
expect_equal(d2$opcode, 0L)
