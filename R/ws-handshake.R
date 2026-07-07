WS_GUID <- "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

#' Compute the Sec-WebSocket-Accept value
#'
#' base64 of the SHA-1 digest of the client key concatenated with the
#' RFC 6455 GUID.
#'
#' @param key character Sec-WebSocket-Key from the client
#' @return character accept key
#' @keywords internal
ws_accept_key <- function(key) {
    digest_bytes <- digest::digest(charToRaw(paste0(key, WS_GUID)),
                                   algo = "sha1", serialize = FALSE,
                                   raw = TRUE)
    gsub("[\r\n]", "", jsonlite::base64_enc(digest_bytes))
}

#' Test whether a header value contains a token
#'
#' Header values like "keep-alive, Upgrade" are comma-separated token
#' lists compared case-insensitively.
#'
#' @param value character header value (or NULL/NA when absent)
#' @param token character lowercase token to look for
#' @return logical
#' @keywords internal
header_has_token <- function(value, token) {
    if (is.null(value) || length(value) != 1L || is.na(value)) {
        return(FALSE)
    }
    tokens <- tolower(trimws(strsplit(value, ",", fixed = TRUE)[[1L]]))
    token %in% tokens
}

#' Is this request a WebSocket upgrade?
#'
#' @param req a parsed request from parse_http_head()
#' @return logical
#' @keywords internal
ws_is_upgrade <- function(req) {
    header_has_token(get_header(req, "upgrade"), "websocket") &&
    header_has_token(get_header(req, "connection"), "upgrade")
}

#' Validate an upgrade request and build the response
#'
#' Pure function: returns ok plus the exact bytes to write, so the
#' whole handshake is testable without sockets. On ok the connection
#' is promoted to a WebSocket; otherwise it is closed after writing.
#'
#' @param req a parsed request from parse_http_head()
#' @return list(ok = logical, response = raw)
#' @keywords internal
ws_handshake_result <- function(req) {
    version <- get_header(req, "sec-websocket-version")
    if (is.null(version) || !identical(trimws(version), "13")) {
        return(list(ok = FALSE, response = http_response_raw(426L,
                    "text/plain", "Upgrade Required",
                    extra_headers = c("Sec-WebSocket-Version" = "13"))))
    }
    key <- get_header(req, "sec-websocket-key")
    if (is.null(key) || nchar(trimws(key)) != 24L) {
        return(list(ok = FALSE, response = http_response_raw(
                    400L, "text/plain", "Bad Request"
                )))
    }
    accept <- ws_accept_key(trimws(key))
    response <- paste0(
                       "HTTP/1.1 101 Switching Protocols\r\n",
                       "Upgrade: websocket\r\n",
                       "Connection: Upgrade\r\n",
                       "Sec-WebSocket-Accept: ", accept, "\r\n",
                       "\r\n"
    )
    # Subprotocols and extensions (notably permessage-deflate) are
    # declined by not echoing them.
    list(ok = TRUE, response = charToRaw(response))
}
