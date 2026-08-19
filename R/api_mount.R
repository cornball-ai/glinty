# The api mount (#72). An application whose domain layer also serves
# non-glinty clients used to need a second HTTP server beside
# run_app(); this file lets it hand run_app(api = ) one pure function
# instead. glinty owns the wire -- parsing, JSON encode/decode, the
# principal -- and the api function owns the routes.

#' Route a request through the mounted api
#'
#' Decodes the request (JSON body, query string, per-request
#' principal), calls the application router, and encodes its answer.
#' NULL from the router means "not mine" and falls through to
#' glinty's own routing.
#'
#' An error inside the router -- or while encoding its answer, so a
#' malformed return shape is covered too -- answers 500 with a generic
#' body; the condition message goes to the server log via message(),
#' never onto the wire, where it could carry paths or SQL to a caller
#' we do not know.
#'
#' @param req parsed request (with raw body when one was sent)
#' @param api the application router (see run_app())
#' @param auth the configured verifier, or NULL
#' @return raw HTTP response, or NULL when the router declined
#' @keywords internal
route_api <- function(req, api, auth = NULL) {
    tryCatch({
        res <- api(req$method, req$path, api_body(req),
                   as.list(parse_query(req$query)), api_principal(req, auth))
        if (is.null(res)) NULL else api_response_raw(res)
    }, error = function(e) {
        message("api request failed: ", conditionMessage(e))
        # The total form, not another api_response_raw() call: the
        # handler must not re-enter the encoder whose failures it
        # exists to catch. Same shape upload.R and download.R answer.
        http_response_raw(500L, "application/json",
                          "{\"error\":\"internal error\"}")
    })
}

#' Decode an api request body as JSON
#'
#' Absent, empty, non-UTF-8, and unparseable bodies all come back
#' NULL: the router sees "no body" and answers as it would for a
#' missing field, rather than glinty deciding what a malformed body
#' deserves.
#'
#' Nothing is simplified: scalars stay scalars, arrays stay lists.
#' Simplification would turn an array of records into an NA-filled
#' data.frame, conflating a field a caller omitted with one it sent
#' as null -- the router owns that distinction, not the wire.
#'
#' @param req parsed request
#' @return a plain nested list, or NULL
#' @keywords internal
api_body <- function(req) {
    if (is.null(req$body) || length(req$body) == 0L) {
        return(NULL)
    }
    txt <- tryCatch(rawToChar(req$body), error = function(e) NULL)
    if (is.null(txt) || !all(validUTF8(txt))) {
        return(NULL)
    }
    # Declared, not just assumed: rawToChar() marks the string
    # "unknown", and on a non-UTF-8 native locale that re-interprets
    # the bytes downstream.
    Encoding(txt) <- "UTF-8"
    tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE),
             error = function(e) NULL)
}

#' Resolve the caller of an api request
#'
#' Runs the same verifier that gates WebSocket sessions, fed the
#' Authorization Bearer token. A verifier declaring a second
#' parameter also receives the request itself, so a session kept in
#' an HttpOnly cookie is visible to it. A verifier that errors
#' yields NULL -- the request proceeds unauthenticated and a
#' default-deny router refuses it, which fails closed without
#' letting a verifier bug take down unauthenticated routes like a
#' ping.
#'
#' @param req parsed request
#' @param auth the configured verifier, or NULL
#' @return whatever the verifier returned, or NULL
#' @keywords internal
api_principal <- function(req, auth) {
    if (is.null(auth)) {
        return(NULL)
    }
    h <- get_header(req, "authorization")
    token <- if (!is.null(h) && grepl("^[Bb]earer ", h)) {
        sub("^[Bb]earer ", "", h)
    } else {
        NULL
    }
    tryCatch({
        if (length(formals(auth)) >= 2L) {
            auth(token, req)
        } else {
            auth(token)
        }
    }, error = function(e) NULL)
}

#' Encode an api result as a raw HTTP response
#'
#' `file` answers binary (content_type given, or guessed from the
#' extension); `json` answers a pre-serialized JSON string verbatim
#' (content_type given, or application/json), for a document that
#' must not be re-encoded (one another library wrote byte-stably,
#' say); a NULL `body` answers empty (204s, redirects); anything else
#' is encoded as JSON with auto-unboxing, the encoding a
#' scalar-in-a-list R payload means. A named `headers` element passes
#' through for Set-Cookie and Location.
#'
#' The shape is checked strictly, and every violation stop()s into
#' route_api's sanitized 500 rather than degrading: an unknown field
#' would otherwise partial-match through `$` and hijack the response
#' (res$json_api_version answering as json =), a typo'd field would
#' answer 200-empty, and a non-numeric status would put "HTTP/1.1 NA"
#' on the wire.
#'
#' @param res list(status =, body = | file = | json =, content_type =,
#'   headers =)
#' @return raw HTTP response
#' @keywords internal
api_response_raw <- function(res) {
    if (!is.list(res)) {
        stop("api router returned ", class(res)[1L], ", not a response list")
    }
    known <- c("status", "body", "json", "file", "content_type", "headers")
    unknown <- setdiff(names(res), known)
    if (length(unknown) > 0L) {
        stop("api response has unknown fields: ",
             paste(unknown, collapse = ", "))
    }
    if (all(!c("body", "json", "file", "status", "headers") %in% names(res))) {
        stop("api response carries no status and no body, json or file")
    }
    status <- res[["status"]]
    if (is.null(status)) {
        status <- 200L
    }
    if (!is.numeric(status) || length(status) != 1L || is.na(status)) {
        stop("api response status must be a single number")
    }
    status <- as.integer(status)
    extra <- api_response_headers(res[["headers"]])
    file <- res[["file"]]
    if (!is.null(file)) {
        if (!file.exists(file)) {
            return(http_response_raw(404L, "text/plain", "Not found", extra))
        }
        ctype <- res[["content_type"]]
        if (is.null(ctype)) {
            ctype <- mime_type(tools::file_ext(file))
        }
        body <- readBin(file, "raw", file.info(file)$size)
        return(http_response_raw(status, ctype, body, extra))
    }
    json <- res[["json"]]
    if (!is.null(json)) {
        if (!is.character(json) || length(json) != 1L || is.na(json) ||
            !nzchar(json)) {
            stop("api json = must be a single non-empty string of ",
                 "pre-serialized JSON")
        }
        ctype <- res[["content_type"]]
        if (is.null(ctype)) {
            ctype <- "application/json"
        }
        return(http_response_raw(status, ctype, json, extra))
    }
    body <- res[["body"]]
    if (is.null(body)) {
        return(http_response_raw(status, "text/plain", "", extra))
    }
    body <- jsonlite::toJSON(body, auto_unbox = TRUE, null = "null")
    http_response_raw(status, "application/json", as.character(body), extra)
}

#' Validate the extra response headers
#'
#' Every element must be named and single-line: an unnamed element
#' emits a malformed head line, and a CR or LF smuggled through a
#' value taken from request data is response splitting. Both refuse
#' loudly into the sanitized 500 instead of going on the wire.
#'
#' @param h the router's headers element, or NULL
#' @return named character vector, or NULL
#' @keywords internal
api_response_headers <- function(h) {
    if (length(h) == 0L) {
        return(NULL)
    }
    v <- unlist(h)
    if (is.null(names(v)) || any(!nzchar(names(v)))) {
        stop("api response headers must all be named")
    }
    if (any(grepl("[\r\n]", v)) || any(grepl("[\r\n]", names(v)))) {
        stop("api response headers must not contain CR or LF")
    }
    v
}
