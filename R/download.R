#' Register a download for this session
#'
#' Wires a download_button() to the bytes it should deliver. The
#' handler is not reactive and not an output: it runs when the browser
#' asks for the file, over a plain GET rather than the WebSocket.
#'
#' filename and content are called at request time, so they see
#' current reactive state. Read any inputs they need through
#' isolate(), since there is no reactive context on an HTTP request.
#'
#' The session id in the URL is the credential, the same as for
#' file_input() uploads and resume. Fine for the localhost and LAN
#' tool scope glinty targets; treat it accordingly.
#'
#' @param session a glinty_session
#' @param id character download ID, matching a download_button()
#' @param filename character name offered to the browser, or a
#'   zero-argument function returning one
#' @param content function(file) that writes the payload to the path
#'   it is given
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' download_handler(
#'     session, "download_audio",
#'     filename = function() paste0("speech-", Sys.Date(), ".wav"),
#'     content = function(file) file.copy(isolate(audio_path()), file)
#' )
#' }
#' @export
download_handler <- function(session, id, filename, content) {
    if (!inherits(session, "glinty_session")) {
        stop("session must be a glinty_session", call. = FALSE)
    }
    if (!is.character(id) || length(id) != 1L || !nzchar(id)) {
        stop("id must be a non-empty character string", call. = FALSE)
    }
    if (!is.function(content)) {
        stop("content must be a function(file)", call. = FALSE)
    }
    if (!is.function(filename) &&
        !(is.character(filename) && length(filename) == 1L)) {
        stop("filename must be a string or a function returning one",
             call. = FALSE)
    }
    session$downloads[[id]] <- list(filename = filename, content = content)
    invisible(NULL)
}

#' Create a download button
#'
#' Renders a link the client points at this session's download route
#' once it knows its session id. The id must match a
#' download_handler() registered on the server.
#'
#' @param id character download ID
#' @param label character button label
#' @param class character extra CSS class(es)
#' @return A UI element
#' @examples
#' download_button("download_audio", "Download")
#' @export
download_button <- function(id, label = "Download", class = NULL) {
    cls <- paste(c("g-btn", "g-download", class), collapse = " ")
    attrs <- list(id = id, class = cls)
    attrs[["data-g-download"]] <- id
    tag("a", text = label, attrs = attrs)
}

#' Serve a registered download
#'
#' @param req a parsed request with a query carrying session and id
#' @return raw HTTP response
#' @keywords internal
handle_download <- function(req) {
    bad <- function(status, msg) {
        http_response_raw(status, "text/plain", msg)
    }
    q <- parse_query(req$query)
    sid <- unname(q["session"])
    dl_id <- unname(q["id"])
    if (is.na(sid) || is.na(dl_id) || !nzchar(sid) || !nzchar(dl_id)) {
        return(bad(400L, "missing session or id"))
    }
    session <- .globals$sessions[[sid]]
    if (is.null(session) || session$ended) {
        return(bad(404L, "unknown session"))
    }
    handler <- session$downloads[[dl_id]]
    if (is.null(handler)) {
        return(bad(404L, "unknown download"))
    }

    name <- tryCatch(
        if (is.function(handler$filename)) {
            handler$filename()
        } else {
            handler$filename
        },
                     error = function(e) NULL
    )
    if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
        return(bad(500L, "download filename failed"))
    }
    name <- basename(name)

    tmp <- tempfile()
    on.exit(unlink(tmp), add = TRUE)
    ok <- tryCatch({
        handler$content(tmp)
        TRUE
    }, error = function(e) FALSE)
    if (!ok || !file.exists(tmp)) {
        return(bad(500L, "download content failed"))
    }

    body <- readBin(tmp, "raw", file.info(tmp)$size)
    headers <- c("Content-Disposition" = paste0("attachment; filename=\"",
            gsub('"', "", name, fixed = TRUE), "\""))
    http_response_raw(200L, mime_type(tools::file_ext(name)), body,
                      extra_headers = headers)
}
