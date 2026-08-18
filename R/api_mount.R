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
#' An error inside the router answers 500 with a generic body; the
#' condition message goes to the server log via message(), never onto
#' the wire, where it could carry paths or SQL to a caller we do not
#' know.
#'
#' @param req parsed request (with raw body when one was sent)
#' @param api the application router (see run_app())
#' @param auth the configured verifier, or NULL
#' @return raw HTTP response, or NULL when the router declined
#' @keywords internal
route_api <- function(req, api, auth = NULL) {
    res <- tryCatch(
                    api(req$method, req$path, api_body(req),
                        as.list(parse_query(req$query)), api_principal(req, auth)),
                    error = function(e) {
        message("api request failed: ", conditionMessage(e))
        list(status = 500L, body = list(error = "internal error"))
    }
    )
    if (is.null(res)) {
        return(NULL)
    }
    api_response_raw(res)
}

#' Decode an api request body as JSON
#'
#' Absent, empty, non-UTF-8, and unparseable bodies all come back
#' NULL: the router sees "no body" and answers as it would for a
#' missing field, rather than glinty deciding what a malformed body
#' deserves.
#'
#' @param req parsed request
#' @return a named list, or NULL
#' @keywords internal
api_body <- function(req) {
    if (is.null(req$body) || length(req$body) == 0L) {
        return(NULL)
    }
    txt <- tryCatch(rawToChar(req$body), error = function(e) NULL)
    if (is.null(txt)) {
        return(NULL)
    }
    tryCatch(jsonlite::fromJSON(txt, simplifyVector = TRUE),
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
#' extension); a NULL `body` answers empty (204s, redirects);
#' anything else is encoded as JSON with auto-unboxing, the encoding
#' a scalar-in-a-list R payload means. A named `headers` element
#' passes through for Set-Cookie and Location.
#'
#' @param res list(status =, body = | file =, content_type =,
#'   headers =)
#' @return raw HTTP response
#' @keywords internal
api_response_raw <- function(res) {
    if (is.null(res$status)) {
        status <- 200L
    } else {
        status <- as.integer(res$status)
    }
    if (length(res$headers)) {
        extra <- unlist(res$headers)
    } else {
        extra <- NULL
    }
    if (!is.null(res$file)) {
        if (!file.exists(res$file)) {
            return(http_response_raw(404L, "text/plain", "Not found", extra))
        }
        ctype <- res$content_type
        if (is.null(ctype)) {
            ctype <- mime_type(tools::file_ext(res$file))
        }
        body <- readBin(res$file, "raw", file.info(res$file)$size)
        return(http_response_raw(status, ctype, body, extra))
    }
    if (is.null(res$body)) {
        return(http_response_raw(status, "text/plain", "", extra))
    }
    body <- jsonlite::toJSON(res$body, auto_unbox = TRUE, null = "null")
    http_response_raw(status, "application/json", as.character(body), extra)
}
