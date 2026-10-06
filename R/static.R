#' The app's static mounts
#'
#' `run_app(static_dir =)` takes one directory, served at /static/,
#' or a named character vector of directories each served under
#' /static/<name>/. The second form is for a page assembled from
#' parts that each bring an asset (a stylesheet, a font, an image):
#' with one directory the parts had to pick one of themselves, or
#' copy into one place at startup, or give up on all but one. One
#' entry may stay unnamed; it is the root mount, serving at /static/
#' whatever no named mount claims.
#'
#' A single unnamed directory that does not exist is skipped: the
#' default "www" is a convenience, not a promise. A named directory
#' that does not exist is refused, because the author named it on
#' purpose and a silently unserved stylesheet is the failure this
#' exists to prevent.
#'
#' @param static_dir NULL, a directory, or a named character vector
#'   of directories
#' @return a named character vector of mounts, the root mount named
#'   "", or NULL when nothing is served
#' @examples
#' \dontrun{
#' run_app(app_obj, static_dir = c(fleet = "/srv/fleet/www",
#'                                 notes = "/srv/notes/www"))
#' # then: page(css = "/static/fleet/style.css")
#' }
#' @export
static_mounts <- function(static_dir) {
    if (is.null(static_dir) || length(static_dir) == 0L) {
        return(NULL)
    }
    if (!is.character(static_dir) || anyNA(static_dir)) {
        stop("static_dir must be NULL, a directory, or a named character ",
             "vector of directories", call. = FALSE)
    }
    nms <- names(static_dir)
    if (is.null(nms)) {
        nms <- rep("", length(static_dir))
    }
    nms[is.na(nms)] <- ""
    if (sum(!nzchar(nms)) > 1L) {
        stop("static_dir may have one unnamed entry (the root mount); ",
             "name the others", call. = FALSE)
    }
    named <- nms[nzchar(nms)]
    bad <- named[!grepl("^[A-Za-z0-9][A-Za-z0-9_.-]*$", named)]
    if (length(bad)) {
        stop("static_dir names must be URL path segments (letters, ",
             "digits, _ - and .): ", paste(bad, collapse = ", "),
             call. = FALSE)
    }
    if (anyDuplicated(named)) {
        stop("static_dir names must be unique: ",
             paste(unique(named[duplicated(named)]), collapse = ", "),
             call. = FALSE)
    }
    keep <- rep(TRUE, length(static_dir))
    for (i in seq_along(static_dir)) {
        if (dir.exists(static_dir[[i]])) {
            next
        }
        if (nzchar(nms[[i]])) {
            stop("static_dir '", nms[[i]], "' is not a directory: ",
                 static_dir[[i]], call. = FALSE)
        }
        keep[[i]] <- FALSE
    }
    mounts <- unname(static_dir[keep])
    names(mounts) <- nms[keep]
    if (length(mounts)) mounts else NULL
}

#' Serve a path under /static/ from the mounts
#'
#' A named mount claims its first path segment; the root mount, when
#' there is one, takes whatever no name claims. A named mount shadows
#' a root directory of the same name, which is the documented order.
#' The traversal guard is serve_static()'s.
#'
#' @param path character the request path after /static/
#' @param mounts a mount vector from static_mounts()
#' @param range character `Range` header value, or NULL
#' @return raw HTTP response
#' @keywords internal
serve_mounted <- function(path, mounts, range = NULL) {
    nms <- names(mounts)
    if (is.null(nms)) {
        nms <- rep("", length(mounts))
    }
    slash <- regexpr("/", path, fixed = TRUE)
    if (slash > 0L) {
        seg <- substr(path, 1L, slash - 1L)
        hit <- which(nzchar(nms) & nms == seg)
        if (length(hit)) {
            return(serve_static(substring(path, slash + 1L), mounts[[hit[[1L]]]],
                                range))
        }
    }
    root <- which(!nzchar(nms))
    if (length(root)) {
        return(serve_static(path, mounts[[root[[1L]]]], range))
    }
    http_response_raw(404L, "text/plain", "Not found")
}
