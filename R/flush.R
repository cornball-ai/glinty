#' Add an observer to the pending flush queue
#'
#' @param obs an observer environment
#' @keywords internal
add_pending_flush <- function(obs) {
    .globals$pending_flush <- c(.globals$pending_flush, list(obs))
}

#' Execute all pending observers
#'
#' Drains the pending queue in priority order (higher priority first).
#' Each observer re-runs, which may invalidate others and add them
#' to the queue.
#'
#' @return invisible(NULL)
#' @examples
#' rv <- reactive_val(1)
#' observe(function() rv())
#' rv(2)
#' flush_reactions()
#' @export
flush_reactions <- function() {
    while (length(.globals$pending_flush) > 0L) {
        queue <- .globals$pending_flush
        .globals$pending_flush <- list()

        # Sort by priority descending
        priorities <- vapply(queue, function(obs) obs$priority, numeric(1))
        queue <- queue[order(priorities, decreasing = TRUE)]

        for (obs in queue) {
            if (!obs$destroyed) {
                obs$run()
            }
        }
    }
    .globals$flush_scheduled <- FALSE
    invisible(NULL)
}

#' Schedule a flush
#'
#' In webR context, sends a message to JS requesting a flush callback.
#' In testing context, sets a flag for manual flushing.
#'
#' @keywords internal
schedule_flush <- function() {
    if (!.globals$flush_scheduled) {
        .globals$flush_scheduled <- TRUE
    }
}

