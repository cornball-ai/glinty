#' Create a new reactive context
#'
#' A context tracks a scope of execution. When any reactive source read
#' during that scope is invalidated, the context's callback fires.
#'
#' @param on_invalidate function called when this context is invalidated
#' @param label character label for debugging
#' @return An environment representing the context
#' @keywords internal
new_context <- function(on_invalidate, label = "") {
    .globals$ctx_id_counter <- .globals$ctx_id_counter + 1L
    ctx <- new.env(parent = emptyenv())
    ctx$id <- .globals$ctx_id_counter
    ctx$label <- label
    ctx$invalidated <- FALSE
    ctx$on_invalidate <- on_invalidate
    ctx$invalidate <- function() {
        if (!ctx$invalidated) {
            ctx$invalidated <- TRUE
            ctx$on_invalidate()
        }
    }
    ctx
}

#' Create a dependents registry
#'
#' Each reactive source holds one of these. Tracks which contexts
#' depend on this source. On invalidation, all dependents are notified.
#'
#' @return An environment with register() and invalidate_all()
#' @keywords internal
new_dependents <- function() {
    self <- new.env(parent = emptyenv())
    self$contexts <- list()

    self$register <- function(ctx) {
        self$contexts[[as.character(ctx$id)]] <- ctx
    }

    self$invalidate_all <- function() {
        ctxs <- self$contexts
        self$contexts <- list()
        for (ctx in ctxs) {
            ctx$invalidate()
        }
    }

    self
}

#' Execute an expression within a reactive context
#'
#' Sets the current context, runs the expression, restores the previous
#' context. Any reactive reads during expr() register the context as
#' a dependent.
#'
#' @param ctx The context environment
#' @param expr A function to execute
#' @return The result of expr()
#' @keywords internal
with_context <- function(ctx, expr) {
    old <- .globals$current_context
    .globals$current_context <- ctx
    on.exit(.globals$current_context <- old)
    expr()
}

#' Run an expression without reactive tracking
#'
#' Reads inside isolate() do not register as dependencies, so the
#' calling observer or expression will not re-run when those values
#' change.
#'
#' @param expr expression to evaluate
#' @return the result of expr
#' @examples
#' rv <- reactive_val(1)
#' isolate(rv())
#' @export
isolate <- function(expr) {
    old <- .globals$current_context
    .globals$current_context <- NULL
    on.exit(.globals$current_context <- old)
    expr
}

