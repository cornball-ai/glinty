#' Current scheduler time
#'
#' Wall-clock seconds. Every scheduler function takes an injectable
#' now so tests can drive the clock by hand.
#'
#' @return numeric epoch seconds
#' @keywords internal
timer_now <- function() {
    as.numeric(Sys.time())
}

#' Schedule a one-shot timer
#'
#' @param delay_s numeric delay in seconds
#' @param fn zero-arg callback
#' @param now numeric current time (injectable for tests)
#' @return integer timer id
#' @keywords internal
schedule_timer <- function(delay_s, fn, now = timer_now()) {
    .globals$timer_id_counter <- .globals$timer_id_counter + 1L
    id <- .globals$timer_id_counter
    timer <- list(id = id, at = now + delay_s, fn = fn)
    timers <- c(.globals$timers, list(timer))
    ats <- vapply(timers, `[[`, numeric(1L), "at")
    .globals$timers <- timers[order(ats)]
    id
}

#' Cancel a scheduled timer
#'
#' @param id integer timer id from schedule_timer()
#' @return invisible(NULL)
#' @keywords internal
cancel_timer <- function(id) {
    ids <- vapply(.globals$timers, `[[`, integer(1L), "id")
    .globals$timers <- .globals$timers[ids != id]
    invisible(NULL)
}

#' Seconds until the next timer fires
#'
#' Used by the event loop as its socketSelect timeout.
#'
#' @param now numeric current time (injectable for tests)
#' @return numeric seconds (>= 0), or NULL if no timers are scheduled
#' @keywords internal
next_timer_deadline <- function(now = timer_now()) {
    if (length(.globals$timers) == 0L) {
        return(NULL)
    }
    max(0, .globals$timers[[1L]]$at - now)
}

#' Run all timers that are due
#'
#' Pops and calls every timer with at <= now, each wrapped in
#' tryCatch so one failing callback cannot take down the loop.
#'
#' @param now numeric current time (injectable for tests)
#' @return integer count of fired timers, invisibly
#' @keywords internal
run_due_timers <- function(now = timer_now()) {
    fired <- 0L
    repeat {
        if (length(.globals$timers) == 0L) {
            break
        }
        timer <- .globals$timers[[1L]]
        if (timer$at > now) {
            break
        }
        .globals$timers <- .globals$timers[-1L]
        tryCatch(timer$fn(), error = function(e) {
            warning("glinty timer callback failed: ", conditionMessage(e),
                call. = FALSE)
        })
        fired <- fired + 1L
    }
    invisible(fired)
}

#' Invalidate the current reactive context after a delay
#'
#' Schedules a one-shot invalidation of the calling observer or
#' reactive, causing it to re-run on the next flush after the delay.
#' Calling it again on re-run re-arms the timer, giving periodic
#' execution (Shiny semantics). Timers belonging to an ended session
#' do nothing when they fire.
#'
#' @param millis numeric delay in milliseconds
#' @param session a glinty_session; defaults to the current session
#' @return invisible(NULL)
#' @examples
#' \dontrun{
#' output$clock <- render_text(function() {
#'     invalidate_later(1000)
#'     format(Sys.time())
#' })
#' }
#' @export
invalidate_later <- function(millis, session = NULL) {
    ctx <- .globals$current_context
    if (is.null(ctx)) {
        stop("invalidate_later() must be called from a reactive context",
            call. = FALSE)
    }
    if (is.null(session)) {
        session <- .globals$current_session
    }
    schedule_timer(millis / 1000, function() {
        if (!is.null(session) && isTRUE(session$ended)) {
            return(invisible(NULL))
        }
        ctx$invalidate()
    })
    invisible(NULL)
}
