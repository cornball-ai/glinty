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
    s$detached <- FALSE
    s$grace_timer <- NULL
    s$last_sent <- new.env(parent = emptyenv())
    s$downloads <- new.env(parent = emptyenv())
    s$send_fn <- send_fn

    s$send <- function(msg) {
        if (s$ended) {
            return(invisible(NULL))
        }
        if (isTRUE(s$detached)) {
            # Buffer non-output messages for a possible resume,
            # capped drop-oldest. Output state is covered by
            # last_sent, so unbounded queues buy nothing.
            cap <- getOption("glinty.detach_buffer", 200L)
            if (length(s$outgoing) >= cap) {
                s$outgoing <- s$outgoing[-1L]
            }
        }
        s$outgoing <- c(s$outgoing, list(msg))
        invisible(NULL)
    }

    # Output-scoped messages: always recorded as the output's latest
    # state (for resume replay); queued only while attached since a
    # resume replays last_sent instead.
    s$send_output <- function(id, msg) {
        if (s$ended) {
            return(invisible(NULL))
        }
        s$last_sent[[id]] <- msg
        if (!isTRUE(s$detached)) {
            s$outgoing <- c(s$outgoing, list(msg))
        }
        invisible(NULL)
    }

    s$on_ended <- function(fn) {
        s$on_ended_cbs <- c(s$on_ended_cbs, list(fn))
        invisible(NULL)
    }

    # Push queued messages to the client right now instead of waiting
    # for the event loop to come back around. The loop is
    # single-threaded, so a long blocking call (an HTTP request to a
    # transcription API, say) starves the normal drain and everything
    # queued behind it arrives at once when the call returns. Progress
    # reporting is the case that needs this: without it, a progress
    # bar would jump from empty to gone.
    s$flush_now <- function() {
        flush_reactions()
        drain_session(s)
        invisible(NULL)
    }

    s$input <- make_input_proxy(s)
    s$output <- make_output_proxy(s)

    class(s) <- "glinty_session"
    .globals$sessions[[id]] <- s
    s
}

#' Detach a session from its transport
#'
#' Called when the WebSocket drops. Observers and timers stay alive;
#' outgoing messages buffer (capped); a grace timer ends the session
#' for real if nobody resumes in time. Idempotent.
#'
#' @param session a glinty_session
#' @return invisible(NULL)
#' @keywords internal
detach_session <- function(session) {
    if (session$ended || isTRUE(session$detached)) {
        return(invisible(NULL))
    }
    session$detached <- TRUE
    grace <- getOption("glinty.resume_grace", 60)
    session$grace_timer <- schedule_timer(grace, function() {
        if (isTRUE(session$detached) && !session$ended) {
            session_end(session)
        }
    })
    invisible(NULL)
}

#' Re-attach a detached session after a resume handshake
#'
#' Cancels the grace timer and queues, in order: a welcome with
#' resumed = TRUE, the last message of every output (current state,
#' no re-render), then whatever non-output messages buffered while
#' detached. The client keeps its live DOM on a resumed welcome, so
#' the tree riding along is ignored there.
#'
#' @param session a glinty_session
#' @return invisible(NULL)
#' @keywords internal
resume_session <- function(session) {
    if (session$ended || !isTRUE(session$detached)) {
        return(invisible(NULL))
    }
    if (!is.null(session$grace_timer)) {
        cancel_timer(session$grace_timer)
        session$grace_timer <- NULL
    }
    session$detached <- FALSE
    replay <- lapply(ls(session$last_sent), function(id) {
        session$last_sent[[id]]
    })
    session$outgoing <- c(list(welcome_msg(session$id, resumed = TRUE)),
                          replay, session$outgoing)
    invisible(NULL)
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
    if (isTRUE(session$detached)) {
        return(invisible(list()))
    }
    msgs <- session$outgoing
    session$outgoing <- list()
    if (!is.null(session$send_fn)) {
        for (m in msgs) {
            session$send_fn(m)
        }
    }
    invisible(msgs)
}
