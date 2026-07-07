#' Create a session
#'
#' A session holds all per-connection reactive state: the input
#' environment, the output registry, queued outgoing messages, and the
#' observers created while this session was current. One browser tab
#' equals one session.
#'
#' @param id character session ID (server-generated)
#' @param send_fn function(msg) used by drain_session() to write a
#'   message to the transport; NULL buffers messages for tests
#' @return A glinty_session environment
#' @keywords internal
new_session <- function(id, send_fn = NULL) {
    s <- new.env(parent = emptyenv())
    s$id <- id
    s$input_env <- new.env(parent = emptyenv())
    s$outgoing <- list()
    s$observers <- list()
    s$on_ended_cbs <- list()
    s$ended <- FALSE
    s$send_fn <- send_fn

    s$send <- function(msg) {
        if (!s$ended) {
            s$outgoing <- c(s$outgoing, list(msg))
        }
        invisible(NULL)
    }

    s$on_ended <- function(fn) {
        s$on_ended_cbs <- c(s$on_ended_cbs, list(fn))
        invisible(NULL)
    }

    s$input <- make_input_proxy(s)
    s$output <- make_output_proxy(s)

    class(s) <- "glinty_session"
    .globals$sessions[[id]] <- s
    s
}

#' End a session
#'
#' Destroys every observer created under the session, fires on_ended
#' callbacks, and removes the session from the registry. Idempotent.
#'
#' @param session a glinty_session
#' @return invisible(NULL)
#' @keywords internal
session_end <- function(session) {
    if (session$ended) {
        return(invisible(NULL))
    }
    session$ended <- TRUE
    for (obs in session$observers) {
        obs$destroy()
    }
    for (cb in session$on_ended_cbs) {
        tryCatch(cb(), error = function(e) NULL)
    }
    session$outgoing <- list()
    if (exists(session$id, envir = .globals$sessions)) {
        rm(list = session$id, envir = .globals$sessions)
    }
    if (identical(.globals$current_session, session)) {
        .globals$current_session <- NULL
    }
    invisible(NULL)
}

#' Evaluate an expression with a session as the current domain
#'
#' Observers created during evaluation are tagged with this session,
#' so session_end() can destroy them.
#'
#' @param session a glinty_session
#' @param expr expression to evaluate
#' @return the result of expr
#' @keywords internal
with_session <- function(session, expr) {
    old <- .globals$current_session
    .globals$current_session <- session
    on.exit(.globals$current_session <- old)
    expr
}

#' Drain a session's outgoing message queue
#'
#' Sends each queued message through the session's send_fn (if any)
#' and returns the drained messages.
#'
#' @param session a glinty_session
#' @return list of character JSON messages, invisibly
#' @keywords internal
drain_session <- function(session) {
    msgs <- session$outgoing
    session$outgoing <- list()
    if (!is.null(session$send_fn)) {
        for (m in msgs) {
            session$send_fn(m)
        }
    }
    invisible(msgs)
}
