#' Observe a single reactive event
#'
#' Runs a handler when an event expression changes, without taking
#' reactive dependencies on anything the handler reads. The event is
#' typically an input accessor: observe_event(input$go, function() ...).
#'
#' @param event_fn a zero-arg function whose tracked reads define the
#'   event (input$id is already such a function)
#' @param handler_fn the handler; zero-arg, or one-arg to receive the
#'   event value
#' @param ignore_init skip the run that happens at creation time
#'   (default TRUE)
#' @param ignore_null skip runs where the event value is not truthy in
#'   the req() sense (default TRUE)
#' @param once destroy the observer after the first handler run
#'   (default FALSE)
#' @param priority numeric priority passed to observe()
#' @param label character label for debugging
#' @return Invisibly, the observer (with $destroy())
#' @examples
#' clicks <- reactive_val(NULL)
#' observe_event(clicks, function(n) message("click ", n))
#' clicks(1)
#' flush_reactions()
#' @export
observe_event <- function(event_fn, handler_fn, ignore_init = TRUE,
                          ignore_null = TRUE, once = FALSE, priority = 0L,
                          label = "") {
    if (!is.function(event_fn)) {
        stop("event_fn must be a function (e.g. input$go)", call. = FALSE)
    }
    takes_value <- length(formals(handler_fn)) >= 1L

    state <- new.env(parent = emptyenv())
    state$first <- TRUE
    state$obs <- NULL
    state$done <- FALSE

    o <- observe(
                 fn = function() {
        val <- event_fn()
        if (state$first) {
            state$first <- FALSE
            if (ignore_init) {
                return(invisible(NULL))
            }
        }
        if (state$done) {
            return(invisible(NULL))
        }
        if (ignore_null && !is_truthy(val)) {
            return(invisible(NULL))
        }
        isolate(if (takes_value) handler_fn(val) else handler_fn())
        if (once) {
            state$done <- TRUE
            if (!is.null(state$obs)) {
                state$obs$destroy()
            }
        }
    },
                 priority = priority, label = label
    )

    state$obs <- o
    if (state$done) {
        o$destroy()
    }
    invisible(o)
}
