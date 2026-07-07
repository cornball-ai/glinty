#' Create a reactive value
#'
#' A reactive value is a get/set container. Call with no arguments to
#' read (and register the current context as a dependent). Call with
#' one argument to write (and invalidate all dependents).
#'
#' @param value initial value (default NULL)
#' @return A function: rv() to get, rv(x) to set
#' @examples
#' rv <- reactive_val(1)
#' rv()
#' rv(2)
#' rv()
#' @export
reactive_val <- function(value = NULL) {
    rv_env <- new.env(parent = emptyenv())
    rv_env$value <- value
    rv_env$deps <- new_dependents()

    rv <- function(x) {
        if (missing(x)) {
            ctx <- .globals$current_context
            if (!is.null(ctx)) {
                rv_env$deps$register(ctx)
            }
            rv_env$value
        } else {
            rv_env$value <- x
            rv_env$deps$invalidate_all()
            schedule_flush()
            invisible(x)
        }
    }

    structure(rv, class = c("reactive_val", "reactive", "function"))
}
