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
#' The GET carries a short-lived single-use ticket the client minted
#' over the WebSocket, so no session credential appears in the URL,
#' browser history, or server logs.
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
#' @param variant character "default", "primary", "secondary",
#'   "danger" or "ghost"
#' @param icon character icon name shown before the label
#' @return A UI component
#' @examples
#' download_button("download_audio", "Download")
#' @export
download_button <- function(id, label = "Download", variant = "default",
                            icon = NULL) {
    component("download_button", id = id, label = label, variant = variant,
              icon = icon)
}

#' Serve a registered download
#'
#' @param req a parsed request with a query carrying a ticket
#' @return raw HTTP response
#' @keywords internal
handle_download <- function(req) {
    bad <- function(status, msg) {
        http_response_raw(status, "text/plain", msg)
    }
    q <- parse_query(req$query)
    grant <- redeem_ticket(unname(q["ticket"]), "download")
    if (is.null(grant)) {
        return(bad(403L, "invalid or expired ticket"))
    }
    session <- grant$session
    handler <- session$downloads[[grant$id]]
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
