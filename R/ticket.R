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
#' @param session a glinty_session
#' @param id character resource id (an input id for uploads, a
#'   download id for downloads)
#' @param purpose "upload" or "download"
#' @return list(token, expires) where expires is the TTL in seconds
#' @keywords internal
issue_ticket <- function(session, id, purpose) {
    prune_tickets()
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

#' Mint an unguessable ticket token
#'
#' Same recipe as session ids: process, clock, counter and a
#' tempfile name through sha1. Unguessable at the "seconds-lived,
#' single-use, LAN tool" scope this serves.
#'
#' @return character token
#' @keywords internal
new_ticket_token <- function() {
    if (is.null(.globals$ticket_counter)) {
        .globals$ticket_counter <- 0L
    }
    .globals$ticket_counter <- .globals$ticket_counter + 1L
    material <- paste("ticket", Sys.getpid(),
                      sprintf("%.9f", as.numeric(Sys.time())),
                      .globals$ticket_counter, tempfile(), sep = "|")
    paste0("tk_", substr(digest::digest(material, algo = "sha1",
                                        serialize = FALSE), 1L, 32L))
}
