# The cross-origin guard on a WebSocket upgrade.
#
# Browsers exempt WebSockets from the same-origin policy: any page a
# user visits may open a socket here, and once open it is fully
# bidirectional -- every input the app has, drivable from a tab the
# user never connected to it, and every output readable back. The
# Origin header is the one part of the handshake a page can neither
# forge nor suppress, so it is the whole defense (#48). An absent
# Origin is allowed on purpose: non-browser clients -- a Flutter
# shell, curl, the tests -- send none, and the same-origin policy
# never applied to them anyway, so refusing them would break real
# clients without stopping any attacker.
#
# CivetWeb performs the handshake; glinty decides, on the ws_connect
# event, before the handshake is answered (see civet_dispatch()).
#
# What this does not stop: DNS rebinding, where the attacker's page
# and this server appear under one attacker-controlled name, so
# Origin and Host agree. That needs a Host allowlist, tracked
# separately.

#' Split a host[:port] authority
#'
#' Handles bracketed IPv6 ("[::1]:8080"). Lowercases, because host
#' names compare case-insensitively.
#'
#' @param value character Host header value or origin authority
#' @return list(host, port) with port NA_integer_ when absent, or
#'   NULL when the value is not a well-formed authority
#' @keywords internal
split_host_port <- function(value) {
    if (!is.character(value) || length(value) != 1L || is.na(value)) {
        return(NULL)
    }
    value <- tolower(trimws(value))
    pattern <- if (startsWith(value, "[")) {
        "^(\\[[0-9a-f:.]+\\])(?::([0-9]+))?$"
    } else {
        "^([^]\\[:/?#@ ]+)(?::([0-9]+))?$"
    }
    m <- regmatches(value, regexec(pattern, value, perl = TRUE))[[1L]]
    if (length(m) == 0L) {
        return(NULL)
    }
    if (nzchar(m[[3L]])) {
        port <- as.integer(m[[3L]])
    } else {
        port <- NA_integer_
    }
    list(host = m[[2L]], port = port)
}

#' Parse an Origin header value
#'
#' @param origin character Origin header value
#' @return list(scheme, host, port) with port NA_integer_ when
#'   implied, or NULL when the value is not scheme://host[:port]
#'   (notably the opaque "null" origin)
#' @keywords internal
origin_parts <- function(origin) {
    if (!is.character(origin) || length(origin) != 1L || is.na(origin)) {
        return(NULL)
    }
    origin <- tolower(trimws(origin))
    m <- regmatches(origin,
                    regexec("^([a-z][a-z0-9+.-]*)://(.+)$", origin, perl = TRUE))[[1L]]
    if (length(m) == 0L) {
        return(NULL)
    }
    hp <- split_host_port(m[[3L]])
    if (is.null(hp)) {
        return(NULL)
    }
    list(scheme = m[[2L]], host = hp$host, port = hp$port)
}

#' The port a scheme implies
#'
#' @param scheme character lowercase scheme
#' @return integer port, or NA_integer_ for schemes with none
#' @keywords internal
scheme_default_port <- function(scheme) {
    switch(scheme, http = 80L, ws = 80L, https = 443L, wss = 443L, NA_integer_)
}

#' Normalize an origin for allowlist comparison
#'
#' Lowercased, default port stripped, so "https://a.example:443" and
#' "https://a.example" are the same entry whichever way the browser
#' or the app spelled it.
#'
#' @param origin character origin string
#' @return character normalized origin, or NULL when unparseable
#' @keywords internal
normalize_origin <- function(origin) {
    p <- origin_parts(origin)
    if (is.null(p)) {
        return(NULL)
    }
    port <- p$port
    if (!is.na(port) && identical(port, scheme_default_port(p$scheme))) {
        port <- NA_integer_
    }
    paste0(p$scheme, "://", p$host, if (!is.na(port)) paste0(":", port) else "")
}

#' Decide whether an upgrade's Origin is acceptable
#'
#' Same-host means the Origin's host equals the request's Host and
#' the ports agree -- explicit ports numerically, an implied origin
#' port (80/443 by scheme) against a portless Host, which is a
#' default-port deployment. The comparison is Origin against Host,
#' never against a hardcoded localhost: an app reached over a tailnet
#' has a tailnet Host, and its own pages must keep connecting.
#'
#' @param origin character Origin header value, or NULL when absent
#' @param host character Host header value, or NULL
#' @param origins character vector of additionally allowed origins,
#'   containing "*" to disable the check, or NULL for same-host only
#' @return logical
#' @keywords internal
ws_origin_allowed <- function(origin, host, origins = NULL) {
    if (is.null(origin)) {
        return(TRUE)
    }
    if (!is.null(origins) && "*" %in% origins) {
        return(TRUE)
    }
    op <- origin_parts(origin)
    if (is.null(op)) {
        # Opaque origins ("null": sandboxed iframes, file://) and
        # malformed values match only a literal allowlist entry, so
        # an app that really means one has to say so.
        return(!is.null(origins) &&
               tolower(trimws(origin)) %in% tolower(trimws(origins)))
    }
    if (!is.null(origins)) {
        allowed <- vapply(origins, function(o) {
            n <- normalize_origin(o)
            if (is.null(n)) NA_character_ else n
        }, character(1L), USE.NAMES = FALSE)
        if (normalize_origin(origin) %in% allowed[!is.na(allowed)]) {
            return(TRUE)
        }
    }
    if (is.null(host)) {
        hp <- NULL
    } else {
        hp <- split_host_port(host)
    }
    if (is.null(hp) || !identical(op$host, hp$host)) {
        return(FALSE)
    }
    if (is.na(op$port)) {
        o_port <- scheme_default_port(op$scheme)
    } else {
        o_port <- op$port
    }
    if (is.na(hp$port)) {
        # A portless Host is a default-port deployment; either
        # scheme's default is the same place.
        return(!is.na(o_port) && o_port %in% c(80L, 443L))
    }
    !is.na(o_port) && o_port == hp$port
}
