#' Create an observer
#'
#' An observer is a side-effect that re-runs whenever its reactive
#' dependencies change. Unlike reactive expressions, observers are
#' eager: they execute on the next flush, not when read.
#'
#' @param fn a function with no arguments that performs side effects
#' @param priority numeric priority (higher runs first, default 0)
#' @param label character label for debugging
#' @return Invisibly, an environment with a $destroy() method
#' @examples
#' rv <- reactive_val("x")
#' obs <- observe(function() message(rv()))
#' obs$destroy()
#' @export
observe <- function(fn, priority = 0L, label = "") {
    obs <- new.env(parent = emptyenv())
    obs$fn <- fn
    obs$priority <- priority
    obs$label <- label
    obs$destroyed <- FALSE
    obs$ctx <- NULL

    # Tag with the current session (the "domain") so session_end()
    # can destroy every observer the session created.
    obs$session <- .globals$current_session
    if (!is.null(obs$session)) {
        obs$session$observers <- c(obs$session$observers, list(obs))
    }

    run <- function() {
        if (obs$destroyed) {
            return()
        }
        obs$ctx <- new_context(
                               on_invalidate = function() {
            if (!obs$destroyed) {
                add_pending_flush(obs)
            }
        },
                               label = label
        )
        with_context(obs$ctx, function() {
            tryCatch(obs$fn(), glinty_silent = function(c) invisible(NULL))
        })
    }

    obs$run <- run
    obs$destroy <- function() {
        obs$destroyed <- TRUE
    }

    # Run immediately to establish initial dependencies
    run()

    invisible(obs)
}
