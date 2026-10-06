# The RFC 6455 frame codec the end-to-end test's client speaks. Pure
# functions on raw vectors, no sockets. The server's framing is
# CivetWeb's; this is only ever the client side, which must mask like
# a browser. Sourced by test_ws_frame.R (which pins it to the RFC's
# sample bytes) and test_e2e.R.

WS_CONT <- 0x0L
WS_TEXT <- 0x1L
WS_BINARY <- 0x2L
WS_CLOSE <- 0x8L
WS_PING <- 0x9L
WS_PONG <- 0xAL

frame_error <- function(code, reason) {
    list(error = TRUE, code = code, reason = reason)
}

# Decode one frame from a buffer: NULL until the buffer holds a whole
# frame, a frame-error record on a protocol violation, or the frame
# plus the unconsumed rest.
ws_decode_frame <- function(buf, max_payload = 1048576L) {
    n <- length(buf)
    if (n < 2L) {
        return(NULL)
    }
    b1 <- as.integer(buf[1L])
    b2 <- as.integer(buf[2L])
    fin <- bitwAnd(b1, 0x80L) != 0L
    if (bitwAnd(b1, 0x70L) != 0L) {
        return(frame_error(1002L, "RSV bits set without extension"))
    }
    opcode <- bitwAnd(b1, 0x0FL)
    masked <- bitwAnd(b2, 0x80L) != 0L
    len7 <- bitwAnd(b2, 0x7FL)

    offset <- 2L
    if (len7 <= 125L) {
        plen <- as.numeric(len7)
    } else if (len7 == 126L) {
        if (n < offset + 2L) {
            return(NULL)
        }
        plen <- as.numeric(buf[offset + 1L]) * 256 +
        as.numeric(buf[offset + 2L])
        offset <- offset + 2L
    } else {
        if (n < offset + 8L) {
            return(NULL)
        }
        if (any(buf[(offset + 1L):(offset + 4L)] != as.raw(0L))) {
            return(frame_error(1009L, "frame too large"))
        }
        b <- as.numeric(buf[(offset + 5L):(offset + 8L)])
        plen <- b[1L] * 16777216 + b[2L] * 65536 + b[3L] * 256 + b[4L]
        offset <- offset + 8L
    }
    if (plen > max_payload) {
        return(frame_error(1009L, "frame too large"))
    }

    mask_key <- NULL
    if (masked) {
        if (n < offset + 4L) {
            return(NULL)
        }
        mask_key <- buf[(offset + 1L):(offset + 4L)]
        offset <- offset + 4L
    }
    if (n < offset + plen) {
        return(NULL)
    }

    payload <- if (plen > 0) {
        buf[(offset + 1L):(offset + plen)]
    } else {
        raw(0L)
    }
    if (masked && plen > 0) {
        payload <- xor(payload, rep_len(mask_key, plen))
    }
    rest <- if (n > offset + plen) {
        buf[(offset + plen + 1L):n]
    } else {
        raw(0L)
    }
    list(fin = fin, opcode = opcode, masked = masked, payload = payload,
         rest = rest)
}

# Encode one frame. A fixed key makes masked encoding deterministic.
ws_encode_frame <- function(opcode, payload = raw(0L), mask = FALSE,
                            fin = TRUE, key = NULL) {
    b1 <- bitwOr(if (fin) 0x80L else 0x00L, bitwAnd(opcode, 0x0FL))
    n <- length(payload)
    mask_bit <- if (mask) 0x80L else 0x00L
    if (n <= 125L) {
        header <- as.raw(c(b1, bitwOr(mask_bit, n)))
    } else if (n <= 65535L) {
        header <- as.raw(c(b1, bitwOr(mask_bit, 126L), n %/% 256L, n %% 256L))
    } else {
        len8 <- integer(8L)
        rem <- n
        for (i in 8:1) {
            len8[i] <- rem %% 256L
            rem <- rem %/% 256L
        }
        header <- as.raw(c(b1, bitwOr(mask_bit, 127L), len8))
    }
    if (!mask) {
        return(c(header, payload))
    }
    if (is.null(key)) {
        key <- as.raw(sample.int(256L, 4L, replace = TRUE) - 1L)
    }
    masked <- if (n > 0) xor(payload, rep_len(key, n)) else raw(0L)
    c(header, key, masked)
}

ws_text_frame <- function(txt, mask = FALSE, key = NULL) {
    ws_encode_frame(WS_TEXT, charToRaw(enc2utf8(txt)), mask = mask, key = key)
}

ws_close_frame <- function(code = 1000L, reason = "", mask = FALSE) {
    payload <- c(as.raw(c(code %/% 256L, code %% 256L)),
                 charToRaw(enc2utf8(reason)))
    ws_encode_frame(WS_CLOSE, payload, mask = mask)
}

ws_pong_frame <- function(payload = raw(0L)) {
    ws_encode_frame(WS_PONG, payload)
}

ws_ping_frame <- function(payload = raw(0L), mask = FALSE) {
    ws_encode_frame(WS_PING, payload, mask = mask)
}
