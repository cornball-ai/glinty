# Authentication. The seam is a function: hello may carry an opaque
# token, run_app(auth = ) takes a verifier, and whatever the verifier
# returns becomes session$principal. glinty never parses, stores, or
# refreshes the token -- it holds a string, hands it over, and keeps
# what comes back. NULL from the verifier refuses the connection.
#
# jwt_auth() is the batteries for the likely case, not part of the
# seam: if the account model lands somewhere other than JWTs, the
# seam is unchanged and jwt_auth() is simply unused.

#' Verify JSON Web Tokens in run_app(auth = )
#'
#' Returns a verifier for `run_app(auth = )` that checks a JWT's
#' signature, `exp` (required), `nbf` (when present) and `aud` (when
#' `aud` is configured), then returns the claims with `sub` copied to
#' `id`. A token that fails any check refuses the connection.
#'
#' The configured algorithm is the law: a token whose header claims a
#' different `alg` is refused without further inspection, which is
#' what closes the classic algorithm-confusion hole.
#'
#' HS256 uses digest's HMAC, RS256 uses openssl; both are Imports, so
#' neither costs an install. Fetching and caching a JWKS is the app's
#' job; hand the chosen key in as `pubkey`.
#'
#' @param secret character HMAC secret, for HS256
#' @param pubkey an RSA public key for RS256: a PEM string, a file
#'   path, or an openssl key object
#' @param algorithm "HS256" or "RS256"
#' @param aud character expected audience, or NULL to skip the check
#' @param leeway numeric seconds of clock slack for exp/nbf
#' @return a function(token) suitable for run_app(auth = )
#' @examples
#' \dontrun{
#' run_app(app_obj,
#'         auth = jwt_auth(secret = Sys.getenv("SUPABASE_JWT_SECRET")))
#' }
#' @export
jwt_auth <- function(secret = NULL, pubkey = NULL,
                     algorithm = c("HS256", "RS256"), aud = NULL, leeway = 30) {
    algorithm <- match.arg(algorithm)
    leeway <- check_theme_number(leeway, "leeway", min = 0, max = 3600)
    if (identical(algorithm, "HS256")) {
        if (!is.character(secret) || length(secret) != 1L || !nzchar(secret)) {
            stop("jwt_auth() with HS256 needs a non-empty secret",
                 call. = FALSE)
        }
    } else {
        if (is.null(pubkey)) {
            stop("jwt_auth() with RS256 needs a pubkey", call. = FALSE)
        }
        pubkey <- openssl::read_pubkey(pubkey)
    }
    force(aud)

    function(token) {
        if (!is.character(token) || length(token) != 1L || !nzchar(token)) {
            return(NULL)
        }
        parts <- strsplit(token, ".", fixed = TRUE)[[1L]]
        if (length(parts) != 3L) {
            return(NULL)
        }
        header <- jwt_part_json(parts[[1L]])
        if (is.null(header) || !identical(header$alg, algorithm)) {
            return(NULL)
        }
        signed <- charToRaw(paste(parts[[1L]], parts[[2L]], sep = "."))
        sig <- b64url_decode(parts[[3L]])
        if (is.null(sig)) {
            return(NULL)
        }
        ok <- if (identical(algorithm, "HS256")) {
            expected <- digest::hmac(key = secret, object = signed,
                                     algo = "sha256", raw = TRUE)
            const_time_eq(sig, expected)
        } else {
            isTRUE(tryCatch(
                            openssl::signature_verify(signed, sig,
                        hash = openssl::sha256,
                        pubkey = pubkey),
                            error = function(e) FALSE
                ))
        }
        if (!ok) {
            return(NULL)
        }
        claims <- jwt_part_json(parts[[2L]])
        if (is.null(claims)) {
            return(NULL)
        }
        now <- as.numeric(Sys.time())
        exp <- suppressWarnings(as.numeric(claims$exp))
        if (length(exp) != 1L || !is.finite(exp) || now > exp + leeway) {
            return(NULL)
        }
        if (!is.null(claims$nbf)) {
            nbf <- suppressWarnings(as.numeric(claims$nbf))
            if (length(nbf) != 1L || !is.finite(nbf) || now < nbf - leeway) {
                return(NULL)
            }
        }
        if (!is.null(aud)) {
            got <- unlist(claims$aud, use.names = FALSE)
            if (!is.character(got) || !aud %in% got) {
                return(NULL)
            }
        }
        claims$id <- claims$sub
        claims
    }
}

#' Run the configured verifier against a hello
#'
#' No verifier means no gate: everything is accepted with a NULL
#' principal, which is what keeps localhost development frictionless.
#' A verifier that errors refuses, the same as returning NULL --
#' failing open on an exception would make a bug in the verifier a
#' bypass of it.
#'
#' @param auth a function(token) or NULL
#' @param msg decoded hello message
#' @return list(ok, principal)
#' @keywords internal
authenticate_hello <- function(auth, msg) {
    if (is.null(auth)) {
        return(list(ok = TRUE, principal = NULL))
    }
    token <- if (is.character(msg$token) && length(msg$token) == 1L) {
        msg$token
    } else {
        NULL
    }
    principal <- tryCatch(auth(token), error = function(e) NULL)
    list(ok = !is.null(principal), principal = principal)
}

#' Is this first frame a hello worth authenticating?
#'
#' The first frame must be a well-formed hello before anything else
#' happens -- before the verifier runs, before a session exists.
#' Anything else is refused outright, which also gives a protocol 2
#' client's init frame an answer instead of a silently dead app.
#'
#' @param msg decoded first frame, or NULL when it failed to parse
#' @return logical
#' @keywords internal
well_formed_hello <- function(msg) {
    is.list(msg) && identical(msg$type, "hello") &&
    length(msg$protocol) == 1L && is.numeric(msg$protocol)
}

#' May this principal resume that session?
#'
#' Authentication binds a session to an identity, and resume must
#' honour the binding: holding a valid token for user B plus user A's
#' session id must not replay A's outputs. The stable identity is
#' principal$id (jwt_auth() puts sub there).
#'
#' A verifier may return anything non-NULL -- a bare string, a
#' vector, a list without an id -- and glinty keeps it as the
#' principal either way. Those simply have no identity to bind to, so
#' resume is disabled for them (a fresh session, not an error): a
#' principal glinty cannot compare is one it must not gamble on.
#'
#' Without auth configured there is no identity at all: the session
#' id alone remains the (documented, weak) resume credential.
#'
#' @param old the detached glinty_session
#' @param principal the freshly verified principal
#' @param auth the configured verifier, or NULL
#' @return logical
#' @keywords internal
resume_allowed <- function(old, principal, auth) {
    if (is.null(auth)) {
        return(TRUE)
    }
    old_id <- principal_id(old$principal)
    new_id <- principal_id(principal)
    !is.null(old_id) && !is.null(new_id) && identical(old_id, new_id)
}

#' The comparable identity in a principal, if it has one
#'
#' @param principal whatever the verifier returned
#' @return a length-1 character id, or NULL when there is none to
#'   compare (including for non-list principals, which cannot carry
#'   one)
#' @keywords internal
principal_id <- function(principal) {
    if (!is.list(principal)) {
        return(NULL)
    }
    id <- principal[["id"]]
    if (is.null(id) || length(id) != 1L || is.na(id)) {
        return(NULL)
    }
    as.character(id)
}

#' Decode one base64url segment
#'
#' @param x character segment
#' @return raw vector, or NULL on malformed input
#' @keywords internal
b64url_decode <- function(x) {
    if (!is.character(x) || length(x) != 1L) {
        return(NULL)
    }
    x <- chartr("-_", "+/", x)
    pad <- (4L - nchar(x) %% 4L) %% 4L
    x <- paste0(x, strrep("=", pad))
    tryCatch(jsonlite::base64_dec(x), error = function(e) NULL)
}

#' Decode one JWT part as JSON
#'
#' @param part character base64url segment
#' @return named list, or NULL on malformed input
#' @keywords internal
jwt_part_json <- function(part) {
    raw <- b64url_decode(part)
    if (is.null(raw)) {
        return(NULL)
    }
    tryCatch(jsonlite::fromJSON(rawToChar(raw), simplifyVector = FALSE),
             error = function(e) NULL)
}

#' Compare two raw vectors in constant time
#'
#' The comparison a signature check needs: every byte is examined
#' regardless of where the first mismatch sits, so timing does not
#' leak the prefix length.
#'
#' @param a,b raw vectors
#' @return logical
#' @keywords internal
const_time_eq <- function(a, b) {
    if (!is.raw(a) || !is.raw(b) || length(a) != length(b)) {
        return(FALSE)
    }
    sum(as.integer(xor(a, b))) == 0L
}
