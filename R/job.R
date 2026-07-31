# Background jobs.
#
# The server is one R process on one select loop, so anything slow
# inside an observer -- a model API call, ffmpeg, a big transform --
# freezes every connected session until it returns. earshot and
# cornfab both hit this; a third app made it structural rather than an
# app's own problem.
#
# The shape: work goes out of process through callr, the handle is
# polled from the event loop's existing timer heap, and completion
# arrives as a reactive value like any other. Nothing crosses the
# wire. A client cannot tell a job from a slow observer except that
# the page stayed alive while it ran.
#
# Two limits worth stating rather than leaving to be discovered:
#
#   - The function runs in a *fresh* R session. It sees its arguments
#     and nothing else -- not the caller's globals, not the session,
#     not an open connection. `k <- 5; run_job(function() k + 1)` fails
#     in the child with "object 'k' not found". Everything it needs
#     goes through args.
#   - Lanes bound this app's concurrency, not the device. Two glinty
#     apps each politely holding themselves to one GPU job still send
#     two requests at the same card, and glinty cannot see that.

#' The lane table an app gets when it asks for nothing
#'
#' Two at a time with eight waiting: enough that a couple of tabs each
#' doing something slow do not queue behind each other, small enough
#' that a runaway loop of run_job() calls is refused rather than
#' forking a hundred R processes.
#'
#' @keywords internal
JOB_DEFAULT_LANES <- list(default = list(concurrency = 2L, queue = 8L))

#' Validate an app's lane settings
#'
#' Lanes merge over the built-in default, so an app naming only a
#' `gpu` lane keeps a `default` lane for everything else. Both fields
#' are required per lane: a queue depth inherited from somewhere else
#' is exactly the kind of number nobody would be able to explain
#' afterwards.
#'
#' @param job_lanes named list of list(concurrency =, queue =), or NULL
#' @return the resolved lane table
#' @keywords internal
resolve_job_lanes <- function(job_lanes = NULL) {
    lanes <- JOB_DEFAULT_LANES
    if (is.null(job_lanes)) {
        return(lanes)
    }
    nms <- names(job_lanes)
    if (!is.list(job_lanes) || is.null(nms) || any(!nzchar(nms)) ||
        anyDuplicated(nms)) {
        stop("job_lanes must be a named list of lane settings, one name ",
             "per lane", call. = FALSE)
    }
    for (nm in nms) {
        cfg <- job_lanes[[nm]]
        if (!is.list(cfg)) {
            stop("job lane '", nm, "' must be a list(concurrency =, queue =)",
                 call. = FALSE)
        }
        # A setting glinty does not read is a setting the author
        # believes is in force. Refuse it where it is written rather
        # than ignore it and run at numbers nobody chose.
        fields <- names(cfg)
        if (length(cfg) > 0L && (is.null(fields) || any(!nzchar(fields)))) {
            stop("job lane '", nm, "': every setting needs a name ",
                 "(concurrency =, queue =)", call. = FALSE)
        }
        unknown <- setdiff(fields, c("concurrency", "queue"))
        if (length(unknown) > 0L) {
            stop("job lane '", nm, "': unknown setting ",
                 paste0("'", unknown, "'", collapse = ", "),
                 "; a lane takes concurrency and queue", call. = FALSE)
        }
        # A list may hold the same name twice, and `cfg$concurrency`
        # takes the first quietly. Two values written down is two
        # intentions, and picking one of them is not this function's
        # business.
        dup <- unique(fields[duplicated(fields)])
        if (length(dup) > 0L) {
            stop("job lane '", nm, "': ", paste(dup, collapse = ", "),
                 " given more than once", call. = FALSE)
        }
        lanes[[nm]] <- list(
                            concurrency = lane_count(cfg$concurrency, nm, "concurrency", 1L),
                            queue = lane_count(cfg$queue, nm, "queue", 0L)
        )
    }
    lanes
}

#' One lane setting, as a whole number
#'
#' Nothing is coerced. `as.integer()` would take `2.5` as 2 and `"2"`
#' as 2, and a lane running at a number its author did not write is
#' worse than one that refused to start: the app comes up, behaves
#' unlike the settings on the screen, and nothing says so.
#'
#' The ceiling is there for the same reason. `as.integer(3e9)` is
#' `NA`, and a lane whose concurrency is `NA` does not fail here --
#' it fails at the first `run_job()`, where `lane_running(lane) < NA`
#' is not a comparison anyone can act on.
#'
#' @param x the supplied value
#' @param lane character lane name, for the message
#' @param field character field name, for the message
#' @param min integer smallest value that means anything
#' @return integer
#' @keywords internal
lane_count <- function(x, lane, field, min) {
    ok <- is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x)
    if (ok) {
        ok <- x == round(x) && x >= min && x <= .Machine$integer.max
    }
    if (!ok) {
        shown <- if (length(x) == 0L) {
            "nothing"
        } else {
            paste(format(x), collapse = ", ")
        }
        stop("job lane '", lane, "': ", field,
             " must be a single whole number from ", min, " to ",
             .Machine$integer.max, " (given: ", shown, ")", call. = FALSE)
    }
    as.integer(x)
}

#' Run a function in a background R process
#'
#' The function is handed to a fresh R session, which is what keeps
#' the event loop free: every other session stays responsive while it
#' runs. Completion arrives reactively -- `job_status()` and
#' `job_result()` are reactive reads, so an output that calls one
#' re-renders when the job settles, with no polling in app code.
#'
#' **The function must be self-contained.** It runs in a session that
#' has never seen the calling environment, so it can use its arguments
#' and packages it loads itself, and nothing else:
#'
#' \preformatted{
#' k <- 5
#' run_job(function() k + 1)              # fails: object 'k' not found
#' run_job(function(k) k + 1, list(k = 5))  # works
#' }
#'
#' Jobs run in a named lane, and the app sizes each lane (see
#' `run_app(job_lanes =)`). With a free slot the job starts at once;
#' under the lane's queue depth it waits; past that it is refused, and
#' the refusal comes back as a handle whose status is `"refused"`
#' rather than as a silent drop or a thirty-deep wait.
#'
#' @param fn a function to run in the background; self-contained, as
#'   above
#' @param args list of arguments to call it with
#' @param lane character lane name; must be one the app configured
#' @param scope "session" (the default) ties the job to the session
#'   that started it: it survives a dropped connection and a resume,
#'   and is killed if the resume grace expires without anyone coming
#'   back. "app" outlives every session and stops only with the app.
#' @return a glinty_job handle. Read it with job_status(),
#'   job_result() and job_error(); stop it with job_cancel().
#' @examples
#' \dontrun{
#' output$answer <- render_text(function() {
#'     switch(job_status(job),
#'            running = "working...",
#'            done = job_result(job),
#'            error = paste("failed:", job_error(job)),
#'            refused = paste("busy:", job_error(job)),
#'            job_status(job))
#' })
#' }
#' @export
run_job <- function(fn, args = list(), lane = "default",
                    scope = c("session", "app")) {
    if (!is.function(fn)) {
        stop("fn must be a function", call. = FALSE)
    }
    if (!is.list(args)) {
        stop("args must be a list", call. = FALSE)
    }
    scope <- match.arg(scope)
    lanes <- .globals$job_lanes
    if (!is.character(lane) || length(lane) != 1L || is.na(lane) ||
        !lane %in% names(lanes)) {
        stop("unknown job lane '", paste(lane, collapse = ", "),
             "'; configured lanes: ", paste(names(lanes), collapse = ", "),
             call. = FALSE)
    }
    session <- NULL
    if (identical(scope, "session")) {
        session <- .globals$current_session
        if (!is.null(session) && isTRUE(session$ended)) {
            # session_end() has already swept this session's jobs, so
            # one started now would never be killed by anything. The
            # way in is an on_ended callback, which runs a few lines
            # after that sweep.
            stop("run_job(scope = \"session\"): this session has ended, and ",
                 "its jobs have already been stopped; use scope = \"app\" for ",
                 "work that should outlive it", call. = FALSE)
        }
        if (is.null(session)) {
            stop("run_job(scope = \"session\") needs a session: call it from ",
                 "server code, or pass scope = \"app\" for work meant to ",
                 "outlive the tab that asked for it", call. = FALSE)
        }
    }

    job <- new_job(fn, args, lane, scope, session)
    cfg <- lanes[[lane]]
    if (lane_running(lane) < cfg$concurrency) {
        register_job(job)
        job_start(job)
    } else if (length(.globals$job_queues[[lane]]) < cfg$queue) {
        register_job(job)
        .globals$job_queues[[lane]] <- c(.globals$job_queues[[lane]], job$id)
    } else {
        # Refusal follows the ticket cap: a value the caller can see,
        # never a silent drop. Someone who queues thirty GPU jobs waits
        # thirty times and concludes the app is broken; refusing at two
        # and saying why is better. A refused job is never registered,
        # so it holds nothing.
        job_settle(job, "refused", error = sprintf(
                paste("job lane '%s' is full (%d running, %d queued);",
                      "try again when one finishes"),
                lane, lane_running(lane), length(.globals$job_queues[[lane]])
            ))
    }
    job
}

#' Build a job handle
#'
#' Status, result and error live in one reactive value rather than
#' three, because they settle together: a reader taking them from
#' separate values could see this run's "done" beside the last run's
#' result in the window between two flushes.
#'
#' @param fn function to run
#' @param args list of arguments
#' @param lane character lane name
#' @param scope "session" or "app"
#' @param session the owning glinty_session, or NULL for app scope
#' @return a glinty_job
#' @keywords internal
new_job <- function(fn, args, lane, scope, session) {
    job <- new.env(parent = emptyenv())
    .globals$job_id_counter <- .globals$job_id_counter + 1L
    job$id <- paste0("job_", .globals$job_id_counter)
    job$fn <- fn
    job$args <- args
    job$lane <- lane
    job$scope <- scope
    if (is.null(session)) {
        job$session_id <- NULL
    } else {
        job$session_id <- session$id
    }
    job$proc <- NULL
    job$progress_file <- NULL
    # Separate from state on purpose: progress changes many times
    # while status changes once, and an output showing a bar should
    # not re-render everything that reads the status.
    job$progress <- reactive_val(NULL)
    job$state <- reactive_val(list(status = "queued", result = NULL,
                                   error = NULL))
    class(job) <- "glinty_job"
    job
}

#' Add a job to the in-flight registry
#'
#' The registry holds queued and running jobs and nothing else --
#' settled jobs drop out of it, so it stays the size of the work
#' actually in flight rather than growing for the life of the app. The
#' handle keeps working either way; it reads its own reactive value.
#'
#' @param job a glinty_job
#' @return invisible(NULL)
#' @keywords internal
register_job <- function(job) {
    .globals$jobs[[job$id]] <- job
    invisible(NULL)
}

#' How many jobs are running in a lane
#'
#' @param lane character lane name
#' @return integer
#' @keywords internal
lane_running <- function(lane) {
    n <- 0L
    for (id in ls(.globals$jobs, all.names = TRUE)) {
        job <- .globals$jobs[[id]]
        if (!is.null(job) && identical(job$lane, lane) &&
            identical(isolate(job$state())$status, "running")) {
            n <- n + 1L
        }
    }
    n
}

#' Start a queued job now
#'
#' A spawn that fails settles the job as an error rather than leaving
#' it queued forever: the loop must never hold work it cannot report
#' on.
#'
#' @param job a glinty_job
#' @return invisible(NULL)
#' @keywords internal
job_start <- function(job) {
    job$progress_file <- tempfile("glinty-progress-", fileext = ".json")
    proc <- tryCatch(job_spawn(job$fn, job$args, job$progress_file),
                     error = function(e) e)
    if (inherits(proc, "condition")) {
        job_settle(job, "error", error = conditionMessage(proc))
        return(invisible(NULL))
    }
    job$proc <- proc
    job$state(list(status = "running", result = NULL, error = NULL))
    job_arm()
    invisible(NULL)
}

#' Settle a job and free its slot
#'
#' @param job a glinty_job
#' @param status one of "done", "error", "cancelled", "refused"
#' @param result the value, for "done"
#' @param error character message, for "error" and "refused"
#' @return invisible(NULL)
#' @keywords internal
job_settle <- function(job, status, result = NULL, error = NULL) {
    job$proc <- NULL
    if (!is.null(job$progress_file)) {
        # No last read here. job_poll() reads progress before it asks
        # whether the process is alive, so the sweep that settles a
        # job has already taken whatever it reported on its way out.
        # A read at this point was unreachable, and a mutation sweep
        # said so: breaking it changed nothing.
        unlink(job$progress_file)
        job$progress_file <- NULL
    }
    if (!is.null(.globals$jobs[[job$id]])) {
        rm(list = job$id, envir = .globals$jobs)
    }
    job$state(list(status = status, result = result, error = error))
    invisible(NULL)
}

#' Start queued jobs in whatever slots are free
#'
#' @return invisible(NULL)
#' @keywords internal
job_pump <- function() {
    for (lane in names(.globals$job_lanes)) {
        cfg <- .globals$job_lanes[[lane]]
        repeat {
            queue <- .globals$job_queues[[lane]]
            if (length(queue) == 0L || lane_running(lane) >= cfg$concurrency) {
                break
            }
            .globals$job_queues[[lane]] <- queue[-1L]
            job <- .globals$jobs[[queue[1L]]]
            if (!is.null(job)) {
                # A start that fails leaves the slot free, and the next
                # turn of this loop takes the job behind it rather than
                # recursing.
                job_start(job)
            }
        }
    }
    invisible(NULL)
}

#' Sweep finished jobs, then fill the slots they freed
#'
#' Runs from the event loop's timer heap, which is the whole point:
#' no second wakeup mechanism, no busy loop, and the sweep stops as
#' soon as nothing is in flight.
#'
#' @return invisible(NULL)
#' @keywords internal
job_poll <- function() {
    # Normally a no-op: the loop pops a timer before calling it, so
    # there is nothing left to cancel. It matters when a sweep is
    # driven by hand, and it makes "at most one job timer is
    # scheduled" true however this was reached.
    if (!is.null(.globals$job_timer)) {
        cancel_timer(.globals$job_timer)
        .globals$job_timer <- NULL
    }
    for (id in ls(.globals$jobs, all.names = TRUE)) {
        job <- .globals$jobs[[id]]
        if (is.null(job) ||
            !identical(isolate(job$state())$status, "running")) {
            next
        }
        # Progress first, liveness second. A job that reports and then
        # exits between two sweeps would otherwise have its last
        # update deleted along with the file, having never been read.
        reported <- job_read_progress(job)
        if (!is.null(reported) &&
                !identical(reported, isolate(job$progress()))) {
            job$progress(reported)
        }
        alive <- tryCatch(job$proc$alive(), error = function(e) FALSE)
        if (isTRUE(alive)) {
            next
        }
        settled <- tryCatch(list(ok = TRUE, value = job$proc$result()),
                            error = function(e) list(ok = FALSE, error = e))
        if (isTRUE(settled$ok)) {
            job_settle(job, "done", result = settled$value)
        } else {
            job_settle(job, "error", error = conditionMessage(settled$error))
        }
    }
    job_pump()
    job_arm()
    invisible(NULL)
}

#' Arm the completion poller if any work is in flight
#'
#' One timer for all jobs, re-armed by each sweep and left unarmed
#' when the registry empties -- so an app that never runs a job pays
#' nothing, and an app between jobs goes back to sleeping in
#' socketSelect for as long as its other timers allow.
#'
#' @return invisible(NULL)
#' @keywords internal
job_arm <- function() {
    if (!is.null(.globals$job_timer)) {
        return(invisible(NULL))
    }
    if (length(ls(.globals$jobs, all.names = TRUE)) == 0L) {
        return(invisible(NULL))
    }
    .globals$job_timer <- schedule_timer(getOption("glinty.job_poll", 0.25),
        job_poll)
    invisible(NULL)
}

#' Stop a job
#'
#' Kills the process if it is running, drops it from its lane's queue
#' if it has not started, and does nothing to a job that has already
#' settled.
#'
#' @param job a glinty_job from run_job()
#' @return TRUE if this call stopped it, FALSE if it was already over
#' @examples
#' \dontrun{
#' observe_event(input$stop, function() job_cancel(job))
#' }
#' @export
job_cancel <- function(job) {
    check_job(job)
    stopped <- job_stop(job)
    if (stopped) {
        job_pump()
    }
    invisible(stopped)
}

#' Stop one job without filling the slot it frees
#'
#' The pump is separated out because cancelling *several* jobs must
#' not start work in between. Killing a session's running job frees a
#' slot; pumping there would start that same session's queued job --
#' spawning an R process, and its startup side effects, for a session
#' that has already ended, only to kill it a moment later. A batch
#' cancels first and pumps once, or not at all when the app is going
#' down.
#'
#' @param job a glinty_job
#' @return TRUE if this call stopped it, FALSE if it was already over
#' @keywords internal
job_stop <- function(job) {
    status <- isolate(job$state())$status
    if (!status %in% c("queued", "running")) {
        return(FALSE)
    }
    if (identical(status, "queued")) {
        queue <- .globals$job_queues[[job$lane]]
        .globals$job_queues[[job$lane]] <- queue[queue != job$id]
    } else if (!is.null(job$proc)) {
        tryCatch(job$proc$kill(), error = function(e) NULL)
    }
    job_settle(job, "cancelled")
    TRUE
}

#' Kill every job a session started
#'
#' Called from session_end() and nowhere else, which is what gives
#' jobs the lifetime the docs claim: a dropped connection only detaches
#' a session, so a job outlives a reconnect and dies when the resume
#' grace expires with nobody having come back.
#'
#' Every one of them is stopped before anything is started, so a
#' session that had one job running and one waiting never spawns the
#' waiting one. The slots freed here do go to other sessions' queued
#' work, which is what the single pump at the end is for.
#'
#' @param session_id character session id
#' @return invisible(NULL)
#' @keywords internal
kill_session_jobs <- function(session_id) {
    stopped <- FALSE
    for (id in ls(.globals$jobs, all.names = TRUE)) {
        job <- .globals$jobs[[id]]
        if (!is.null(job) && identical(job$session_id, session_id)) {
            stopped <- job_stop(job) || stopped
        }
    }
    # The server carries on, so whoever else was waiting gets the room.
    if (stopped) {
        job_pump()
    }
    invisible(NULL)
}

#' Kill every job, whatever its scope
#'
#' For app shutdown. callr's supervisor would reap the children when
#' this process exits anyway; this makes it happen at a moment we
#' choose, and leaves the registry clean for the next run_app() in the
#' same session.
#'
#' Nothing is pumped: the loop is going away, and starting a queued
#' job here would spawn an R process for work that is about to be
#' killed.
#'
#' @return invisible(NULL)
#' @keywords internal
kill_all_jobs <- function() {
    for (id in ls(.globals$jobs, all.names = TRUE)) {
        job <- .globals$jobs[[id]]
        if (!is.null(job)) {
            job_stop(job)
        }
    }
    if (!is.null(.globals$job_timer)) {
        cancel_timer(.globals$job_timer)
        .globals$job_timer <- NULL
    }
    .globals$job_queues <- list()
    invisible(NULL)
}

#' A job's status, reactively
#'
#' One of "queued", "running", "done", "error", "cancelled" or
#' "refused". Reading it inside a renderer or observer registers a
#' dependency, so that output re-renders when the job settles.
#'
#' @param job a glinty_job from run_job()
#' @return character status
#' @examples
#' \dontrun{
#' output$state <- render_text(function() job_status(job))
#' }
#' @export
job_status <- function(job) {
    check_job(job)
    job$state()$status
}

#' A job's return value, reactively
#'
#' NULL until the job is done, and NULL forever if it errored or was
#' cancelled -- so a job whose function legitimately returns NULL is
#' told apart by job_status(), not by this.
#'
#' @param job a glinty_job from run_job()
#' @return the value the function returned, or NULL
#' @examples
#' \dontrun{
#' output$answer <- render_text(function() job_result(job))
#' }
#' @export
job_result <- function(job) {
    check_job(job)
    job$state()$result
}

#' Why a job failed or was refused, reactively
#'
#' The child's error message for an "error", the lane and its
#' occupancy for a "refused", NULL otherwise. Both come back as text
#' for the same reason: an app that has to show the user why nothing
#' happened should not need two code paths to say it.
#'
#' @param job a glinty_job from run_job()
#' @return character message, or NULL
#' @examples
#' \dontrun{
#' output$why <- render_text(function() job_error(job))
#' }
#' @export
job_error <- function(job) {
    check_job(job)
    job$state()$error
}

#' Refuse anything that is not a job handle
#'
#' @param job the supposed handle
#' @return invisible(NULL)
#' @keywords internal
check_job <- function(job) {
    if (!inherits(job, "glinty_job")) {
        stop("job must be a handle from run_job()", call. = FALSE)
    }
    invisible(NULL)
}

#' Print a job handle
#'
#' @param x a glinty_job
#' @param ... ignored
#' @return x, invisibly
#' @examples
#' \dontrun{
#' print(run_job(function() 1, scope = "app"))
#' }
#' @export
print.glinty_job <- function(x, ...) {
    state <- isolate(x$state())
    cat(sprintf("<glinty job %s> lane=%s scope=%s status=%s\n", x$id, x$lane,
                x$scope, state$status))
    if (!is.null(state$error)) {
        cat("  ", state$error, "\n", sep = "")
    }
    invisible(x)
}

#' Start a background R process
#'
#' The one seam between glinty and callr. Everything above this line
#' knows a process only as three functions -- alive(), result(),
#' kill() -- which is what lets the tests drive completion, failure
#' and killing by hand instead of waiting on real processes.
#'
#' @param fn function to run
#' @param args list of arguments
#' @param progress_file character path the child reports progress to,
#'   passed in the environment so it costs the job's function no
#'   argument of its own
#' @return list(alive, result, kill)
#' @keywords internal
job_spawn <- function(fn, args, progress_file = NULL) {
    spawner <- getOption("glinty.job_spawner", NULL)
    if (is.function(spawner)) {
        return(spawner(fn, args, progress_file))
    }
    out <- tempfile("glinty-job-", fileext = ".out")
    err <- tempfile("glinty-job-", fileext = ".err")
    env <- callr::rcmd_safe_env()
    if (!is.null(progress_file)) {
        env <- c(env, GLINTY_JOB_PROGRESS = progress_file)
    }
    proc <- callr::r_bg(func = fn, args = args, supervise = TRUE,
                        stdout = out, stderr = err, env = env)
    # Piped output would be the default. A job that prints steadily and
    # is never read from fills the pipe buffer and blocks in the child,
    # which is the one failure this whole file exists to avoid; files
    # cannot do that.
    done <- function() unlink(c(out, err))
    list(
         alive = function() proc$is_alive(),
         result = function() {
        on.exit(done(), add = TRUE)
        tryCatch(proc$get_result(),
                 error = function(e) stop(job_failure(e, err), call. = FALSE))
    },
         kill = function() {
        on.exit(done(), add = TRUE)
        proc$kill()
    }
    )
}

#' Where this process reports job progress, if it is a job
#'
#' Set on the child by job_spawn(), read by set_progress() and
#' inc_progress(). An environment variable rather than an argument
#' because the job's function belongs to the app: adding a parameter
#' to it would make every job that wants progress take one, and every
#' job that does not carry a spare.
#'
#' @return character path, or NULL in a process that is not a job
#' @keywords internal
job_progress_path <- function() {
    path <- Sys.getenv("GLINTY_JOB_PROGRESS", "")
    if (nzchar(path)) path else NULL
}

#' Write this job's progress where the server will read it
#'
#' Overwritten rather than appended: progress is a level, not a
#' stream. Only the newest value means anything, and a file that grows
#' with every update makes each poll cost more than the one before.
#'
#' @param value numeric fraction, or NULL to leave it
#' @param detail character secondary line, or NULL
#' @param message character headline, or NULL
#' @param add logical treat value as an increment
#' @return TRUE if this process is a job and the write was attempted
#' @keywords internal
job_report_progress <- function(value = NULL, detail = NULL, message = NULL,
                                add = FALSE) {
    path <- job_progress_path()
    if (is.null(path)) {
        return(FALSE)
    }
    last <- .globals$job_progress_last
    if (is.null(last)) {
        last <- list(value = 0, message = "", detail = "")
    }
    if (!is.null(value)) {
        last$value <- clamp_progress(if (add) last$value + value else value)
    }
    if (!is.null(message)) {
        last$message <- message
    }
    if (!is.null(detail)) {
        last$detail <- detail
    }
    .globals$job_progress_last <- last
    line <- as.character(jsonlite::toJSON(last, auto_unbox = TRUE))
    # A job whose progress file cannot be written is still a job. The
    # work matters; the bar does not. An unopenable path warns before
    # it errors, so both are swallowed -- a warning surfacing from the
    # child would land in stderr and read as a failure of the work.
    tryCatch(suppressWarnings(writeLines(line, path)),
             error = function(e) NULL)
    TRUE
}

#' Read what a job last reported
#'
#' @param job a glinty_job
#' @return list(value, message, detail), or NULL
#' @keywords internal
job_read_progress <- function(job) {
    path <- job$progress_file
    if (is.null(path) || !file.exists(path)) {
        return(NULL)
    }
    lines <- tryCatch(readLines(path, warn = FALSE),
                      error = function(e) character(0))
    lines <- lines[nzchar(lines)]
    if (length(lines) == 0L) {
        return(NULL)
    }
    # A read that lands mid-write sees a truncated line. Ignoring it
    # costs one update; the next poll has the whole thing.
    tryCatch(jsonlite::fromJSON(lines[length(lines)], simplifyVector = TRUE),
             error = function(e) NULL)
}

#' What a job last reported, reactively
#'
#' NULL until the job reports something. Inside the job, report with
#' the same `set_progress()` and `inc_progress()` an in-process
#' operation would use -- they notice they are running in a background
#' process and write where the server is reading:
#'
#' \preformatted{
#' job <- run_job(function(n) {
#'     for (i in seq_len(n)) {
#'         glinty::set_progress(i / n, detail = paste("step", i))
#'         one_step(i)
#'     }
#' }, args = list(n = 10))
#'
#' output$bar <- render_text(function() {
#'     p <- job_progress(job)
#'     if (is.null(p)) "starting" else paste0(round(p$value * 100), "%")
#' })
#' }
#'
#' Updates arrive when the poller next runs, so the resolution is
#' `getOption("glinty.job_poll", 0.25)` seconds rather than every call
#' the job makes.
#'
#' @param job a glinty_job from run_job()
#' @return list(value, message, detail), or NULL
#' @examples
#' \dontrun{
#' output$pct <- render_text(function() job_progress(job)$value)
#' }
#' @export
job_progress <- function(job) {
    check_job(job)
    job$progress()
}

#' Why a background job failed, in one message
#'
#' callr reports the remote condition when the child returned an
#' error, and very little when the child died without returning at all
#' -- a segfault in a linked library, an out-of-memory kill. stderr is
#' the only account of that, so its tail is joined on rather than left
#' in a temp file nobody will think to look for.
#'
#' @param e the condition callr raised
#' @param err_file character path to the child's stderr
#' @return character message
#' @keywords internal
job_failure <- function(e, err_file) {
    msg <- conditionMessage(e)
    tail_txt <- job_tail(err_file)
    if (nzchar(tail_txt)) {
        paste0(msg, "\n", tail_txt)
    } else {
        msg
    }
}

#' The last few non-blank lines of a file
#'
#' @param path character file path
#' @param n integer how many lines
#' @return character, "" when there is nothing to read
#' @keywords internal
job_tail <- function(path, n = 20L) {
    if (!file.exists(path)) {
        return("")
    }
    lines <- tryCatch(readLines(path, warn = FALSE),
                      error = function(e) character(0))
    lines <- lines[nzchar(trimws(lines))]
    if (length(lines) == 0L) {
        return("")
    }
    paste(utils::tail(lines, n), collapse = "\n")
}
