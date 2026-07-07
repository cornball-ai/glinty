#' Handle a file upload POST
#'
#' POST /upload?session=<sid>&id=<input_id> with a multipart body.
#' File parts are written under a per-session temp dir (removed when
#' the session ends) and the input becomes a data.frame with one row
#' per file: name, size, type, datapath. Dependent outputs update
#' over the WebSocket on the next tick.
#'
#' @param req parsed request with raw body
#' @return raw HTTP response
#' @keywords internal
handle_upload <- function(req) {
    bad <- function(status, msg) {
        http_response_raw(status, "application/json",
            sprintf('{"ok":false,"error":"%s"}', msg))
    }
    q <- parse_query(req$query)
    sid <- unname(q["session"])
    input_id <- unname(q["id"])
    if (is.na(sid) || is.na(input_id) || !nzchar(sid) ||
        !nzchar(input_id)) {
        return(bad(400L, "missing session or id"))
    }
    session <- .globals$sessions[[sid]]
    if (is.null(session) || session$ended) {
        return(bad(404L, "unknown session"))
    }
    boundary <- extract_boundary(get_header(req, "content-type"))
    if (is.null(boundary)) {
        return(bad(400L, "expected multipart/form-data"))
    }
    parts <- parse_multipart(req$body, boundary)
    files <- list()
    for (name in names(parts)) {
        for (part in parts[[name]]) {
            if (!is.na(part$filename) && nzchar(part$filename)) {
                files <- c(files, list(part))
            }
        }
    }
    if (length(files) == 0L) {
        return(bad(400L, "no file parts"))
    }

    dir <- session_upload_dir(session)
    rows <- lapply(files, function(p) {
        # basename() defuses hostile filenames; the stored name is
        # informational, the datapath is ours
        fname <- basename(p$filename)
        ext <- tolower(tools::file_ext(fname))
        datapath <- tempfile("upload-", tmpdir = dir,
            fileext = if (nzchar(ext)) paste0(".", ext) else "")
        writeBin(p$value, datapath)
        data.frame(name = fname, size = length(p$value),
            type = NA_character_, datapath = datapath,
            stringsAsFactors = FALSE)
    })
    handle_input(session, input_id, do.call(rbind, rows))
    http_response_raw(200L, "application/json", '{"ok":true}')
}

#' Lazily create a session's upload directory
#'
#' Registered for recursive removal when the session ends.
#'
#' @param session a glinty_session
#' @return character directory path
#' @keywords internal
session_upload_dir <- function(session) {
    if (is.null(session$upload_dir)) {
        d <- file.path(tempdir(), paste0("glinty-upload-", session$id))
        dir.create(d, showWarnings = FALSE, recursive = TRUE)
        session$upload_dir <- d
        session$on_ended(function() unlink(d, recursive = TRUE))
    }
    session$upload_dir
}
