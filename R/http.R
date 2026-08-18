# Buffer-based HTTP parsing and response writing. The event loop's
# connections are non-blocking, so nothing here reads from a socket;
# parsing operates on the bytes a connection has already buffered.

#' Find the end of an HTTP head in a buffer
#'
#' @param buf raw vector
#' @return integer index of the first byte of the CRLFCRLF
#'   terminator, or -1 if not present yet
#' @keywords internal
find_header_end <- function(buf) {
    n <- length(buf)
    if (n < 4L) {
        return(-1L)
    }
    cr <- which(buf[seq_len(n - 3L)] == as.raw(13L))
    for (i in cr) {
        if (buf[i + 1L] == as.raw(10L) &&
            buf[i + 2L] == as.raw(13L) &&
            buf[i + 3L] == as.raw(10L)) {
            return(i)
        }
    }
    -1L
}

#' Parse an HTTP request head
#'
#' @param head_raw raw bytes of the request line and headers (without
#'   the terminating CRLFCRLF)
#' @return list(method, path, query, headers) with lower-cased header
#'   names, or NULL on a malformed head
#' @keywords internal
parse_http_head <- function(head_raw) {
    txt <- tryCatch(rawToChar(head_raw), error = function(e) NULL)
    if (is.null(txt)) {
        return(NULL)
    }
    lines <- strsplit(txt, "\r\n", fixed = TRUE)[[1L]]
    if (length(lines) < 1L) {
        return(NULL)
    }

    parts <- strsplit(lines[1L], " ", fixed = TRUE)[[1L]]
    if (length(parts) < 2L) {
        return(NULL)
    }
    method <- parts[1L]
    target <- parts[2L]

    path <- target
    query <- ""
    qpos <- regexpr("?", target, fixed = TRUE)
    if (qpos > 0L) {
        path <- substr(target, 1L, qpos - 1L)
        query <- substr(target, qpos + 1L, nchar(target))
    }

    headers <- character(0L)
    if (length(lines) > 1L) {
        hl <- lines[-1L]
        hl <- hl[nzchar(hl)]
        has_colon <- grepl(":", hl, fixed = TRUE)
        hl <- hl[has_colon]
        keys <- tolower(sub(":.*$", "", hl))
        vals <- trimws(sub("^[^:]*:", "", hl))
        names(vals) <- keys
        headers <- vals
    }
    list(method = method, path = path, query = query, headers = headers)
}

#' Look up a request header
#'
#' headers is a named character vector; [[ on a missing vector name
#' errors, so lookups go through here.
#'
#' @param req a parsed request
#' @param name character lower-case header name
#' @return character value, or NULL when absent
#' @keywords internal
get_header <- function(req, name) {
    h <- req$headers
    if (name %in% names(h)) {
        unname(h[[name]])
    } else {
        NULL
    }
}

#' Build a complete HTTP response
#'
#' Always Connection: close -- the page loads once and the WebSocket
#' carries the app afterwards, so keep-alive buys nothing.
#'
#' @param status integer HTTP status code
#' @param content_type character MIME type
#' @param body character or raw response body
#' @param extra_headers named character vector of additional headers
#' @return raw bytes of the full response
#' @keywords internal
http_response_raw <- function(status, content_type, body,
                              extra_headers = NULL) {
    reason <- switch(as.character(status), "200" = "OK", "201" = "Created",
                     "204" = "No Content", "206" = "Partial Content",
                     "302" = "Found", "400" = "Bad Request",
                     "401" = "Unauthorized", "403" = "Forbidden",
                     "404" = "Not Found", "413" = "Payload Too Large",
                     "416" = "Range Not Satisfiable",
                     "426" = "Upgrade Required", "429" = "Too Many Requests",
                     "500" = "Internal Server Error",
                     "501" = "Not Implemented", "OK")
    if (is.character(body)) {
        body <- charToRaw(paste(body, collapse = ""))
    }
    extra <- ""
    if (length(extra_headers) > 0L) {
        extra <- paste0(
                        paste0(names(extra_headers), ": ", extra_headers,
                               collapse = "\r\n"),
                        "\r\n"
        )
    }
    header <- paste0(
                     "HTTP/1.1 ", status, " ", reason, "\r\n",
                     "Content-Type: ", content_type, "\r\n",
                     "Content-Length: ", length(body), "\r\n",
                     extra,
                     "Connection: close\r\n",
                     "\r\n"
    )
    c(charToRaw(header), body)
}

#' Parse a byte-range request header
#'
#' Handles the single-range forms a media element actually sends:
#' `bytes=from-to`, `bytes=from-` (to the end) and `bytes=-suffix` (the
#' last n bytes). Anything else, multi-range included, returns `NULL`:
#' the whole file is always a valid answer to a range request, so an
#' unparsed header costs a fall back rather than an error.
#'
#' @param range character `Range` header value, or NULL
#' @param size numeric file size in bytes
#' @return `NULL` to serve the whole file, `NA` when the range names
#'   bytes the file does not have (a 416), otherwise `list(from, to)`
#'   with inclusive zero-based offsets
#' @keywords internal
parse_range <- function(range, size) {
    if (is.null(range) || length(range) != 1L || is.na(range) ||
        !nzchar(range)) {
        return(NULL)
    }
    m <- regmatches(range, regexec("^bytes=([0-9]*)-([0-9]*)$", trimws(range)))[[1]]
    if (length(m) != 3L || (!nzchar(m[2]) && !nzchar(m[3]))) {
        return(NULL)
    }
    if (!is.finite(size) || size <= 0) {
        return(NA)
    }
    if (nzchar(m[2])) {
        from <- as.numeric(m[2])
        if (nzchar(m[3])) {
            to <- as.numeric(m[3])
        } else {
            to <- size - 1
        }
        if (from >= size) {
            return(NA)
        }
        to <- min(to, size - 1)
    } else {
        n <- as.numeric(m[3]) # suffix: the last n bytes
        if (n <= 0) {
            return(NA)
        }
        from <- max(0, size - n)
        to <- size - 1
    }
    if (to < from) {
        return(NA)
    }
    list(from = from, to = to)
}

#' Serve a file from a static directory
#'
#' Keeps browseR's traversal guard and MIME table, and answers byte-range
#' requests.
#'
#' Ranges are what make a `<video>` seekable: without them the element
#' can play from the start but every scrub re-fetches the file, and the
#' whole thing passes through memory each time. Every response advertises
#' `Accept-Ranges: bytes`, because a client that is not told it can seek
#' will not try.
#'
#' @param file_name character path relative to dir
#' @param dir character directory to serve from
#' @param range character `Range` header value, or NULL for the whole file
#' @return raw HTTP response
#' @keywords internal
serve_static <- function(file_name, dir, range = NULL) {
    if (grepl("..", file_name, fixed = TRUE)) {
        return(http_response_raw(403L, "text/plain", "Forbidden"))
    }
    file_path <- file.path(dir, file_name)
    if (!file.exists(file_path) || dir.exists(file_path)) {
        return(http_response_raw(404L, "text/plain", "Not found"))
    }
    size <- file.info(file_path)$size
    ctype <- mime_type(tools::file_ext(file_path))
    span <- parse_range(range, size)
    if (is.null(span)) {
        body <- readBin(file_path, "raw", size)
        return(http_response_raw(200L, ctype, body,
                                 c("Accept-Ranges" = "bytes")))
    }
    if (!is.list(span)) {
        return(http_response_raw(416L, "text/plain", "Range Not Satisfiable",
                                 c("Accept-Ranges" = "bytes",
                                   "Content-Range" = paste0("bytes */", size))))
    }
    con <- file(file_path, "rb")
    on.exit(close(con), add = TRUE)
    if (span$from > 0) {
        seek(con, where = span$from)
    }
    body <- readBin(con, "raw", span$to - span$from + 1)
    http_response_raw(206L, ctype, body,
                      c("Accept-Ranges" = "bytes",
                        "Content-Range" = sprintf("bytes %.0f-%.0f/%.0f",
                span$from, span$to, size)))
}

#' Map a file extension to a MIME type
#'
#' webm is registered as video/webm for the container, but glinty
#' produces audio-only webm and an <audio> element wants audio/webm.
#' It stays audio here for that reason: a served .webm is one glinty
#' wrote. mp4/m4v/mov carry no such history and map to video, which is
#' what a <video> element needs to play a file at all.
#'
#' @param ext character file extension, with or without case
#' @return character MIME type, falling back to
#'   application/octet-stream
#' @keywords internal
mime_type <- function(ext) {
    switch(tolower(ext), "js" = "application/javascript", "css" = "text/css",
           "html" = "text/html", "txt" = "text/plain", "csv" = "text/csv",
           "png" = "image/png", "jpg" = "image/jpeg", "jpeg" = "image/jpeg",
           "gif" = "image/gif", "webp" = "image/webp",
           "svg" = "image/svg+xml", "ico" = "image/x-icon",
           "wav" = "audio/wav", "mp3" = "audio/mpeg", "m4a" = "audio/mp4",
           "ogg" = "audio/ogg", "flac" = "audio/flac", "webm" = "audio/webm",
           "mp4" = "video/mp4", "m4v" = "video/mp4",
           "mov" = "video/quicktime", "woff" = "font/woff",
           "woff2" = "font/woff2", "pdf" = "application/pdf",
           "zip" = "application/zip", "json" = "application/json",
           "application/octet-stream")
}
