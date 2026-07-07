# RFC 6455 frame codec. Pure functions on raw vectors -- no sockets --
# so every path is unit-testable byte-for-byte and composes with the
# event loop's per-connection buffers.

# Opcodes
WS_CONT <- 0x0L
WS_TEXT <- 0x1L
WS_BINARY <- 0x2L
WS_CLOSE <- 0x8L
WS_PING <- 0x9L
WS_PONG <- 0xAL

#' Signal a protocol error from the decoder
#'
#' @param code integer WebSocket close code
#' @param reason character human-readable reason
#' @return a frame-error record
#' @keywords internal
frame_error <- function(code, reason) {
    list(error = TRUE, code = code, reason = reason)
}

#' Decode one frame from a buffer
#'
#' Returns NULL when the buffer does not yet hold a complete frame
#' (caller keeps the bytes and waits), a frame-error record on
#' protocol violations, or the decoded frame plus the unconsumed rest
#' of the buffer. Masking policy is the caller's: the decoded frame
#' reports masked so servers can require it.
#'
#' @param buf raw vector
#' @param max_payload integer payload cap per frame
#' @return NULL, frame-error, or list(fin, opcode, masked, payload, rest)
#' @keywords internal
ws_decode_frame <- function(buf,
                            max_payload = getOption("glinty.max_frame", 1048576L)) {
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
        # 64-bit length: require the high 4 bytes to be zero so the
        # low word stays exact in a double.
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

#' Encode one frame
#'
#' Server frames are never masked; mask = TRUE exists for the test
#' client, which must mask like a browser. A fixed key makes masked
#' encoding deterministic for tests.
#'
#' @param opcode integer frame opcode
#' @param payload raw payload
#' @param mask logical whether to mask (client role)
#' @param fin logical final-fragment flag
#' @param key raw(4) mask key; random when NULL
#' @return raw frame bytes
#' @keywords internal
ws_encode_frame <- function(opcode, payload = raw(0L), mask = FALSE,
                            fin = TRUE, key = NULL) {
    b1 <- bitwOr(if (fin) 0x80L else 0x00L, bitwAnd(opcode, 0x0FL))
    n <- length(payload)
    if (mask) {
        mask_bit <- 0x80L
    } else {
        mask_bit <- 0x00L
    }
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
    if (n > 0) {
        masked <- xor(payload, rep_len(key, n))
    } else {
        masked <- raw(0L)
    }
    c(header, key, masked)
}

#' Encode a text frame
#'
#' @param txt character scalar
#' @param mask logical whether to mask (client role)
#' @param key raw(4) mask key; random when NULL
#' @return raw frame bytes
#' @keywords internal
ws_text_frame <- function(txt, mask = FALSE, key = NULL) {
    ws_encode_frame(WS_TEXT, charToRaw(enc2utf8(txt)), mask = mask, key = key)
}

#' Encode a close frame
#'
#' @param code integer close code
#' @param reason character reason text
#' @param mask logical whether to mask (client role)
#' @return raw frame bytes
#' @keywords internal
ws_close_frame <- function(code = 1000L, reason = "", mask = FALSE) {
    payload <- c(as.raw(c(code %/% 256L, code %% 256L)),
                 charToRaw(enc2utf8(reason)))
    ws_encode_frame(WS_CLOSE, payload, mask = mask)
}

#' Encode a pong frame
#'
#' @param payload raw payload echoed from the ping
#' @return raw frame bytes
#' @keywords internal
ws_pong_frame <- function(payload = raw(0L)) {
    ws_encode_frame(WS_PONG, payload)
}

#' Encode a ping frame (test client)
#'
#' @param payload raw payload
#' @param mask logical whether to mask (client role)
#' @return raw frame bytes
#' @keywords internal
ws_ping_frame <- function(payload = raw(0L), mask = FALSE) {
    ws_encode_frame(WS_PING, payload, mask = mask)
}
