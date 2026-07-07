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
    reason <- switch(as.character(status), "200" = "OK",
                     "400" = "Bad Request", "403" = "Forbidden",
                     "404" = "Not Found", "426" = "Upgrade Required",
                     "500" = "Internal Server Error", "OK")
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

#' Serve a file from a static directory
#'
#' Keeps browseR's traversal guard and MIME table.
#'
#' @param file_name character path relative to dir
#' @param dir character directory to serve from
#' @return raw HTTP response
#' @keywords internal
serve_static <- function(file_name, dir) {
    if (grepl("..", file_name, fixed = TRUE)) {
        return(http_response_raw(403L, "text/plain", "Forbidden"))
    }
    file_path <- file.path(dir, file_name)
    if (!file.exists(file_path) || dir.exists(file_path)) {
        return(http_response_raw(404L, "text/plain", "Not found"))
    }
    ext <- tools::file_ext(file_path)
    ct <- switch(ext, "js" = "application/javascript", "css" = "text/css",
                 "html" = "text/html", "png" = "image/png",
                 "jpg" = "image/jpeg", "jpeg" = "image/jpeg",
                 "svg" = "image/svg+xml", "ico" = "image/x-icon",
                 "wav" = "audio/wav", "mp3" = "audio/mpeg",
                 "json" = "application/json", "application/octet-stream")
    body <- readBin(file_path, "raw", file.info(file_path)$size)
    http_response_raw(200L, ct, body)
}
