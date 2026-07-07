# multipart/form-data parsing, ported from whisper's server (the
# .serve_parse_multipart design: binary-safe raw splitting via
# grepRaw, no string coercion of file content). Generalized: repeated
# field names accumulate as separate parts instead of being merged.

#' Extract the boundary from a Content-Type header
#'
#' @param ct character content-type header value
#' @return character boundary, or NULL if this is not multipart
#' @keywords internal
extract_boundary <- function(ct) {
    if (is.null(ct) || !grepl("multipart/form-data", ct, fixed = TRUE) ||
        !grepl("boundary=", ct, fixed = TRUE)) {
        return(NULL)
    }
    # base R regex has no backreferences; strip quotes separately
    trimws(gsub('"', "", sub(".*boundary=([^;]+).*", "\\1", ct)))
}

#' Parse a multipart/form-data body
#'
#' @param body raw request body
#' @param boundary character boundary string (without leading --)
#' @return named list; each element is a LIST of parts (one per
#'   occurrence of the field name), each part being
#'   list(value = raw, filename = character or NA)
#' @keywords internal
parse_multipart <- function(body, boundary) {
    if (length(body) == 0L) {
        return(list())
    }
    delim <- charToRaw(paste0("--", boundary))
    pos <- grepRaw(delim, body, all = TRUE, fixed = TRUE)
    if (length(pos) < 2L) {
        return(list())
    }
    dlen <- length(delim)
    hdr_term <- as.raw(c(13L, 10L, 13L, 10L))
    crlf <- as.raw(c(13L, 10L))
    parts <- list()

    for (i in seq_len(length(pos) - 1L)) {
        seg <- body[(pos[i] + dlen):(pos[i + 1L] - 1L)]
        if (length(seg) < 2L) {
            next
        }
        # The closing delimiter is "--boundary--": segment starts "--"
        if (seg[1L] == as.raw(0x2d) && seg[2L] == as.raw(0x2d)) {
            next
        }
        # Strip the CRLF after the boundary and the trailing CRLF
        if (seg[1L] == crlf[1L] && seg[2L] == crlf[2L]) {
            seg <- seg[-(1:2)]
        }
        n <- length(seg)
        if (n >= 2L && seg[n - 1L] == crlf[1L] && seg[n] == crlf[2L]) {
            seg <- seg[1:(n - 2L)]
        }
        hp <- grepRaw(hdr_term, seg, fixed = TRUE)
        if (length(hp) == 0L) {
            next
        }
        hdr_txt <- rawToChar(seg[1:(hp - 1L)])
        content <- if ((hp + 4L) <= length(seg)) {
            seg[(hp + 4L):length(seg)]
        } else {
            raw(0L)
        }

        cd <- grep("content-disposition",
                   strsplit(hdr_txt, "\r\n", fixed = TRUE)[[1L]],
                   ignore.case = TRUE, value = TRUE)[1L]
        if (is.na(cd)) {
            next
        }
        # Require a delimiter before name= so the greedy match does
        # not grab filename= instead
        name <- if (grepl('[ ;]name="', cd)) {
            sub('.*[ ;]name="([^"]*)".*', "\\1", cd)
        } else {
            NA_character_
        }
        filename <- if (grepl('filename="', cd)) {
            sub('.*filename="([^"]*)".*', "\\1", cd)
        } else {
            NA_character_
        }
        if (is.na(name)) {
            next
        }
        part <- list(value = content, filename = filename)
        if (is.null(parts[[name]])) {
            parts[[name]] <- list(part)
        } else {
            parts[[name]] <- c(parts[[name]], list(part))
        }
    }
    parts
}

#' Parse a URL query string
#'
#' @param q character query string (no leading ?)
#' @return named character vector of decoded values
#' @keywords internal
parse_query <- function(q) {
    if (is.null(q) || !nzchar(q)) {
        return(character(0L))
    }
    pairs <- strsplit(q, "&", fixed = TRUE)[[1L]]
    pairs <- pairs[nzchar(pairs)]
    keys <- sub("=.*$", "", pairs)
    vals <- ifelse(grepl("=", pairs, fixed = TRUE), sub("^[^=]*=", "", pairs),
                   "")
    vals <- vapply(vals, function(v) {
        URLdecode(chartr("+", " ", v))
    }, character(1L), USE.NAMES = FALSE)
    names(vals) <- vapply(keys, URLdecode, character(1L), USE.NAMES = FALSE)
    vals
}
