# Transfer tickets. Uploads and downloads are plain HTTP, so they
# cannot ride the WebSocket's authentication. Protocol 2 put the
# session id in the URL, which made it a bearer credential in browser
# history and server logs. v3 mints a short-lived single-use ticket
# per transfer, over the socket, scoped to one session, one resource
# id, and one purpose.
#
# The ticket is an opaque random token held server-side, not a signed
# payload: a single-process server IS the authority on what it
# issued, and a store it can consult beats cryptography it could get
# wrong. Signing earns its place when tickets must be verified by a
# process that did not mint them, which is not this architecture.

#' Issue a transfer ticket for one resource
#'
#' Bounded per session even within the TTL: pruning expired tickets
#' does not stop a client minting thousands inside one TTL window,
#' and no real page runs dozens of simultaneous transfers. At the cap
#' the request is dropped; a legitimate client retries after its
#' in-flight transfers finish.
#'
#' @param session a glinty_session
#' @param id character resource id (an input id for uploads, a
#'   download id for downloads)
#' @param purpose "upload" or "download"
#' @return list(token, expires) where expires is the TTL in seconds,
#'   or NULL at the session's live-ticket cap
#' @keywords internal
issue_ticket <- function(session, id, purpose) {
    prune_tickets()
    live <- 0L
    for (tk in ls(.globals$tickets, all.names = TRUE)) {
        if (identical(.globals$tickets[[tk]]$session_id, session$id)) {
            live <- live + 1L
        }
    }
    if (live >= 64L) {
        return(NULL)
    }
    ttl <- getOption("glinty.ticket_ttl", 30)
    token <- new_ticket_token()
    .globals$tickets[[token]] <- list(session_id = session$id, id = id,
                                      purpose = purpose,
                                      expires = as.numeric(Sys.time()) + ttl)
    list(token = token, expires = ttl)
}

#' Redeem a ticket, once
#'
#' The ticket is consumed whether or not the transfer that follows
#' succeeds: a retry asks for a new one over the socket, which costs
#' nothing, and a replayed URL gets nothing.
#'
#' @param token character ticket token from the URL
#' @param purpose "upload" or "download"; a ticket minted for one
#'   never opens the other
#' @return list(session, id), or NULL when the ticket is unknown,
#'   expired, for another purpose, or its session is gone
#' @keywords internal
redeem_ticket <- function(token, purpose) {
    if (!is.character(token) || length(token) != 1L || !nzchar(token)) {
        return(NULL)
    }
    entry <- .globals$tickets[[token]]
    if (is.null(entry)) {
        return(NULL)
    }
    rm(list = token, envir = .globals$tickets)
    if (!identical(entry$purpose, purpose)) {
        return(NULL)
    }
    if (as.numeric(Sys.time()) > entry$expires) {
        return(NULL)
    }
    session <- .globals$sessions[[entry$session_id]]
    if (is.null(session) || session$ended) {
        return(NULL)
    }
    list(session = session, id = entry$id)
}

#' Drop expired tickets
#'
#' Called on every issue, so an app that mints tickets and never
#' redeems them still holds a bounded set.
#'
#' @return invisible(NULL)
#' @keywords internal
prune_tickets <- function() {
    now <- as.numeric(Sys.time())
    for (token in ls(.globals$tickets, all.names = TRUE)) {
        if (now > .globals$tickets[[token]]$expires) {
            rm(list = token, envir = .globals$tickets)
        }
    }
    invisible(NULL)
}

#' Mint a ticket token
#'
#' A ticket is a bearer credential, so the token comes from a real
#' CSPRNG, never from hashed process state a peer could reconstruct.
#'
#' @return character token
#' @keywords internal
new_ticket_token <- function() {
    paste0("tk_", raw_to_hex(random_bytes(16L)))
}

#' Cryptographically random bytes
#'
#' One source, every platform: openssl's CSPRNG. This is why openssl
#' is an Import rather than a Suggests -- session ids and tickets are
#' bearer credentials on every platform glinty runs on, base R has no
#' CSPRNG, and /dev/urandom is not a cross-platform answer (a Windows
#' server would have silently fallen through to an error, or worse to
#' something weaker). A dependency that is always needed belongs in
#' Imports.
#'
#' @param n integer byte count
#' @return raw vector of length n
#' @keywords internal
random_bytes <- function(n) {
    openssl::rand_bytes(n)
}

#' Lowercase hex of a raw vector
#'
#' @param x raw vector
#' @return character
#' @keywords internal
raw_to_hex <- function(x) {
    paste(sprintf("%02x", as.integer(x)), collapse = "")
}
