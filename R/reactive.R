#' Create a reactive expression
#'
#' A reactive expression is a lazy, cached computation. It re-evaluates
#' only when an upstream source changes. Reading it registers the caller
#' as a dependent.
#'
#' @param fn a function with no arguments that computes the value
#' @param label character label for debugging
#' @return A function: re() returns the (possibly cached) value
#' @examples
#' rv <- reactive_val(5)
#' doubled <- reactive(function() rv() * 2)
#' doubled()
#' @export
reactive <- function(fn, label = "") {
    re_env <- new.env(parent = emptyenv())
    re_env$fn <- fn
    re_env$value <- NULL
    re_env$dirty <- TRUE
    re_env$deps <- new_dependents()
    re_env$ctx <- NULL

    invalidate_self <- function() {
        re_env$dirty <- TRUE
        re_env$deps$invalidate_all()
    }

    re <- function() {
        # Register caller as dependent on this expression
        caller_ctx <- .globals$current_context
        if (!is.null(caller_ctx)) {
            re_env$deps$register(caller_ctx)
        }

        if (re_env$dirty) {
            # Create a fresh context for this computation
            re_env$ctx <- new_context(invalidate_self, label = label)
            re_env$value <- with_context(re_env$ctx, re_env$fn)
            re_env$dirty <- FALSE
        }

        re_env$value
    }

    structure(re, class = c("reactive_expr", "reactive", "function"))
}
