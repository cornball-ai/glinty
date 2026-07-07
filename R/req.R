#' Require truthy values
#'
#' Aborts the current observer or renderer silently (no error message,
#' no output update) if any argument is not truthy: NULL, empty,
#' all-NA, FALSE, or an empty string. Mirrors Shiny's req().
#'
#' @param ... values to require
#' @return the first argument, invisibly, if all are truthy
#' @examples
#' rv <- reactive_val(NULL)
#' obs <- observe(function() {
#'     req(rv())
#'     message("only reached once rv is truthy")
#' })
#' @export
req <- function(...) {
    args <- list(...)
    for (a in args) {
        if (!is_truthy(a)) {
            cond <- structure(class = c("glinty_silent", "condition"),
                              list(message = "", call = NULL))
            stop(cond)
        }
    }
    if (length(args) >= 1L) {
        invisible(args[[1L]])
    } else {
        invisible(NULL)
    }
}

#' Test whether a value is truthy
#'
#' @param x a value
#' @return logical
#' @keywords internal
is_truthy <- function(x) {
    if (is.null(x)) {
        return(FALSE)
    }
    if (is.function(x)) {
        return(TRUE)
    }
    if (length(x) == 0L) {
        return(FALSE)
    }
    if (all(is.na(x))) {
        return(FALSE)
    }
    if (is.logical(x)) {
        return(any(x[!is.na(x)]))
    }
    if (is.character(x)) {
        return(any(nzchar(x[!is.na(x)])))
    }
    TRUE
}
