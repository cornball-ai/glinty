# Background jobs.
#
# The process is faked for almost all of this: a job's whole
# observable life is "is it alive, what did it return, can it be
# killed", and driving those three by hand tests the queueing, the
# lane arithmetic and the lifetime in milliseconds instead of waiting
# on real R sessions. The callr seam itself is exercised for real at
# the bottom, where it is the thing under test rather than a delay.

.g <- getFromNamespace(".globals", "glinty")

resolve_job_lanes <- glinty:::resolve_job_lanes
job_poll <- glinty:::job_poll
lane_running <- glinty:::lane_running
kill_all_jobs <- glinty:::kill_all_jobs
new_session <- glinty:::new_session
session_end <- glinty:::session_end
detach_session <- glinty:::detach_session
resume_session <- glinty:::resume_session
with_session <- glinty:::with_session
run_due_timers <- glinty:::run_due_timers

reset_jobs <- function(lanes = glinty:::JOB_DEFAULT_LANES) {
    .g$jobs <- new.env(parent = emptyenv())
    .g$job_queues <- list()
    .g$job_lanes <- lanes
    .g$job_timer <- NULL
    .g$timers <- list()
    .g$pending_flush <- list()
    .g$current_session <- NULL
    .g$current_context <- NULL
    spawned <<- list()
}

# --- lane settings ---
expect_equal(resolve_job_lanes(), glinty:::JOB_DEFAULT_LANES)

# an app naming one lane keeps the default lane for everything else
lanes <- resolve_job_lanes(list(gpu = list(concurrency = 1, queue = 2)))
expect_equal(sort(names(lanes)), c("default", "gpu"))
expect_equal(lanes$gpu$concurrency, 1L)
expect_equal(lanes$default$queue, 8L)

# and naming the default lane resizes it
expect_equal(resolve_job_lanes(list(default = list(concurrency = 4,
                                                   queue = 1)))$default$concurrency,
             4L)

# both fields are required: a queue depth inherited from somewhere
# else is a number nobody could explain afterwards
expect_error(resolve_job_lanes(list(gpu = list(concurrency = 1))))
expect_error(resolve_job_lanes(list(gpu = list(queue = 1))))
expect_error(resolve_job_lanes(list(gpu = list(concurrency = 0, queue = 1))))
expect_error(resolve_job_lanes(list(gpu = list(concurrency = 1, queue = -1))))
expect_error(resolve_job_lanes(list(list(concurrency = 1, queue = 1))))
expect_error(resolve_job_lanes(list(gpu = 1)))

# Nothing is coerced. as.integer() would read 2.5 as 2 and "2" as 2,
# and a lane running at a number its author did not write is worse
# than one that refused to start: the app comes up, behaves unlike the
# settings on the screen, and nothing says so.
for (bad in list(2.5, "2", "two", TRUE, Inf, NA, NULL, c(1, 2), list(1))) {
    expect_error(resolve_job_lanes(list(gpu = list(concurrency = bad,
                                                   queue = 1))),
                 pattern = "whole number")
}
# and a setting glinty does not read is refused where it is written,
# rather than ignored while the author believes it is in force
expect_error(resolve_job_lanes(list(gpu = list(concurrency = 1, queue = 1,
                                               priority = "high"))),
             pattern = "unknown setting 'priority'")
expect_error(resolve_job_lanes(list(gpu = list(1, 2))),
             pattern = "every setting needs a name")
# a queue of 0 is a lane that refuses rather than waits, which is
# legitimate
expect_equal(resolve_job_lanes(list(gpu = list(concurrency = 1,
                                               queue = 0)))$gpu$queue, 0L)

# --- a process whose life the test drives ---
spawned <- list()
fake_spawner <- function(fn, args) {
    proc <- new.env(parent = emptyenv())
    proc$alive <- TRUE
    proc$value <- NULL
    proc$fail <- NULL
    proc$killed <- FALSE
    proc$fn <- fn
    proc$args <- args
    spawned[[length(spawned) + 1L]] <<- proc
    list(
        alive = function() proc$alive,
        result = function() {
            if (!is.null(proc$fail)) {
                stop(proc$fail, call. = FALSE)
            }
            proc$value
        },
        kill = function() {
            proc$killed <- TRUE
            proc$alive <- FALSE
        }
    )
}
options(glinty.job_spawner = fake_spawner)

finishes <- function(proc, value) {
    proc$alive <- FALSE
    proc$value <- value
    invisible(proc)
}
fails <- function(proc, msg) {
    proc$alive <- FALSE
    proc$fail <- msg
    invisible(proc)
}

# --- a job with a free slot starts at once ---
reset_jobs()
j1 <- run_job(function(x) x + 1, args = list(x = 1), scope = "app")
expect_equal(job_status(j1), "running")
expect_null(job_result(j1))
expect_null(job_error(j1))
expect_equal(length(spawned), 1L)
# the function and its arguments reach the spawner unchanged
expect_equal(spawned[[1]]$args, list(x = 1))
expect_equal(spawned[[1]]$fn(1), 2)
# and the poller is armed, on the loop's own timer heap
expect_false(is.null(.g$job_timer))
expect_equal(length(.g$timers), 1L)

# --- completion settles, and settles reactively ---
seen <- character(0)
observe(function() seen <<- c(seen, job_status(j1)))
expect_equal(seen, "running")

job_poll()
expect_equal(job_status(j1), "running")

finishes(spawned[[1]], 42)
job_poll()
expect_equal(job_status(j1), "done")
expect_equal(job_result(j1), 42)
flush_reactions()
expect_equal(seen, c("running", "done"))

# nothing is in flight, so the poller is not re-armed: an app between
# jobs goes back to sleeping in socketSelect
expect_null(.g$job_timer)
expect_equal(length(.g$timers), 0L)

# a settled job leaves the registry; the handle keeps working
expect_equal(length(ls(.g$jobs)), 0L)
expect_equal(job_status(j1), "done")

# --- an error settles as an error, and says why ---
reset_jobs()
j2 <- run_job(function() stop("nope"), scope = "app")
fails(spawned[[1]], "the child fell over")
job_poll()
expect_equal(job_status(j2), "error")
expect_true(grepl("the child fell over", job_error(j2), fixed = TRUE))
expect_null(job_result(j2))

# a job that returns NULL is done, not empty-because-unfinished: the
# status is what tells them apart, which is why job_result() alone
# cannot
reset_jobs()
j3 <- run_job(function() NULL, scope = "app")
finishes(spawned[[1]], NULL)
job_poll()
expect_equal(job_status(j3), "done")
expect_null(job_result(j3))

# --- concurrency: past the slots, jobs wait ---
reset_jobs(list(default = list(concurrency = 1L, queue = 4L)))
a <- run_job(function() 1, scope = "app")
b <- run_job(function() 2, scope = "app")
expect_equal(job_status(a), "running")
expect_equal(job_status(b), "queued")
# the second was never spawned, which is the point of the cap
expect_equal(length(spawned), 1L)
expect_equal(lane_running("default"), 1L)

finishes(spawned[[1]], "a")
job_poll()
expect_equal(job_status(a), "done")
expect_equal(job_status(b), "running")
expect_equal(length(spawned), 2L)

# --- the queue is a FIFO ---
reset_jobs(list(default = list(concurrency = 1L, queue = 4L)))
jobs <- lapply(1:4, function(i) {
    run_job(function(i) i, args = list(i = i), scope = "app")
})
expect_equal(vapply(jobs, job_status, character(1)),
             c("running", "queued", "queued", "queued"))
for (i in 1:3) {
    finishes(spawned[[i]], i)
    job_poll()
}
# they started in the order they were asked for
expect_equal(vapply(spawned, function(p) p$args$i, numeric(1)), c(1, 2, 3, 4))
expect_equal(job_status(jobs[[4]]), "running")

# --- at the queue depth, refuse with a reason ---
reset_jobs(list(default = list(concurrency = 1L, queue = 1L)))
r1 <- run_job(function() 1, scope = "app")
r2 <- run_job(function() 2, scope = "app")
r3 <- run_job(function() 3, scope = "app")
expect_equal(job_status(r3), "refused")
expect_true(grepl("full", job_error(r3), fixed = TRUE))
expect_true(grepl("default", job_error(r3), fixed = TRUE))
# a refusal is a value the caller can see, and holds nothing: the
# refused job is not in the registry and not in the queue
expect_equal(length(ls(.g$jobs)), 2L)
expect_equal(length(.g$job_queues[["default"]]), 1L)
expect_equal(length(spawned), 1L)
# and it stays refused: nothing later starts it
finishes(spawned[[1]], 1)
job_poll()
expect_equal(job_status(r3), "refused")
expect_equal(job_status(r2), "running")

# a lane with no queue at all refuses immediately
reset_jobs(list(default = list(concurrency = 1L, queue = 0L)))
run_job(function() 1, scope = "app")
expect_equal(job_status(run_job(function() 2, scope = "app")), "refused")

# --- lanes are independent ---
reset_jobs(list(default = list(concurrency = 2L, queue = 8L),
                gpu = list(concurrency = 1L, queue = 1L)))
g1 <- run_job(function() 1, lane = "gpu", scope = "app")
g2 <- run_job(function() 2, lane = "gpu", scope = "app")
g3 <- run_job(function() 3, lane = "gpu", scope = "app")
expect_equal(job_status(g3), "refused")
# a full gpu lane says nothing about the default lane
d1 <- run_job(function() 4, scope = "app")
expect_equal(job_status(d1), "running")
expect_equal(lane_running("gpu"), 1L)
expect_equal(lane_running("default"), 1L)

# a lane nobody configured is a typo, not a capacity condition
expect_error(run_job(function() 1, lane = "gpu2", scope = "app"))
expect_error(run_job(function() 1, lane = c("gpu", "default"), scope = "app"))

# --- cancelling ---
reset_jobs(list(default = list(concurrency = 1L, queue = 4L)))
c1 <- run_job(function() 1, scope = "app")
c2 <- run_job(function() 2, scope = "app")
c3 <- run_job(function() 3, scope = "app")

# a queued job leaves the queue and never spawns
expect_true(job_cancel(c2))
expect_equal(job_status(c2), "cancelled")
expect_equal(.g$job_queues[["default"]], c3$id)

# a running job is killed, and its slot goes to whoever is next
expect_true(job_cancel(c1))
expect_true(spawned[[1]]$killed)
expect_equal(job_status(c1), "cancelled")
expect_equal(job_status(c3), "running")

# cancelling something already over is a no-op that says so
finishes(spawned[[2]], "c3")
job_poll()
expect_equal(job_status(c3), "done")
expect_false(job_cancel(c3))
expect_equal(job_status(c3), "done")

expect_error(job_cancel("not a job"))
expect_error(job_status(list()))

# --- an app sizes its lanes, and bad settings stop it starting ---
#
# Before the port is resolved and long before a socket is opened: an
# app with a lane it cannot honour should not come up at all.
#
# Each of these asserts the message, not just that something failed.
# run_app() has plenty of other ways to error -- a port in use, for one
# -- and an expect_error() that takes any of them would still pass with
# the lane check deleted.
tiny_app <- app(ui = page(text_output("x")),
                server = function(input, output) NULL)
expect_error(run_app(tiny_app, job_lanes = list(gpu = list(concurrency = 0,
                                                           queue = 1))),
             pattern = "concurrency must be a single whole number")
expect_error(run_app(tiny_app, job_lanes = list(gpu = list(concurrency = 1))),
             pattern = "queue must be a single whole number")
expect_error(run_app(tiny_app, job_lanes = "two at a time"),
             pattern = "named list of lane settings")

# --- bad arguments ---
reset_jobs()
expect_error(run_job("not a function", scope = "app"))
expect_error(run_job(function() 1, args = "not a list", scope = "app"))
# session scope with no session says what to do about it rather than
# quietly running unowned work
expect_error(run_job(function() 1))

# --- starting a job takes no reactive dependency on the jobs already
# running ---
#
# run_job() counts what is running in the lane, and that count reads
# every in-flight job's state. Read without isolate(), from anything
# that has a reactive context -- an observer, a renderer -- those
# reads register the caller as a dependent of jobs it merely counted.
# The first one to finish would then re-run it, which starts another
# job, which counts the rest: a loop that spawns R processes until the
# lane refuses.
reset_jobs()
counted <- run_job(function() 1, scope = "app")
runs <- 0L
observe(function() {
    runs <<- runs + 1L
    run_job(function() 2, scope = "app")
})
expect_equal(runs, 1L)
finishes(spawned[[1]], "counted")
job_poll()
flush_reactions()
expect_equal(job_status(counted), "done")
expect_equal(runs, 1L)

# --- session scope, and the lifetime it actually has ---
reset_jobs()
s <- new_session("job-session")
with_session(s, {
    sj <- run_job(function() 1)
    aj <- run_job(function() 2, scope = "app")
})
expect_equal(job_status(sj), "running")
expect_equal(job_status(aj), "running")

session_end(s)
# the session's job is killed; the app-scoped one beside it is not
expect_equal(job_status(sj), "cancelled")
expect_true(spawned[[1]]$killed)
expect_equal(job_status(aj), "running")
expect_false(spawned[[2]]$killed)

# a queued session job is dropped too, not left in the lane forever
# -- and never started on the way out.
#
# Killing the running job frees a slot. Pumping there would start this
# same session's queued job: a real R process, with whatever its
# startup does, for a session that has already ended, killed again a
# moment later. Ending as "cancelled" is true either way, so the
# status alone cannot see it. The spawn count can.
reset_jobs(list(default = list(concurrency = 1L, queue = 4L)))
s2 <- new_session("job-session-2")
with_session(s2, {
    q1 <- run_job(function() 1)
    q2 <- run_job(function() 2)
})
expect_equal(job_status(q2), "queued")
expect_equal(length(spawned), 1L)
session_end(s2)
expect_equal(job_status(q2), "cancelled")
expect_equal(length(.g$job_queues[["default"]]), 0L)
expect_equal(length(spawned), 1L)

# and nothing new attaches to a session that is already over: the
# sweep has been and gone, so a job started now would never be killed
# by anything.
s2a <- new_session("job-session-2a")
session_end(s2a)
orphan <- with_session(s2a, tryCatch(run_job(function() 1),
                                     error = function(e) e))
expect_true(inherits(orphan, "error"))
expect_true(grepl("session has ended", conditionMessage(orphan), fixed = TRUE))
expect_equal(length(ls(.g$jobs)), 0L)

# but the room does go to somebody else who was waiting: the server
# carries on, and one pump follows the batch
reset_jobs(list(default = list(concurrency = 1L, queue = 4L)))
s2b <- new_session("job-session-2b")
with_session(s2b, mine <- run_job(function() 1))
theirs <- run_job(function() 2, scope = "app")
expect_equal(job_status(theirs), "queued")
session_end(s2b)
expect_equal(job_status(mine), "cancelled")
expect_equal(job_status(theirs), "running")
expect_equal(length(spawned), 2L)

# --- a dropped socket is not a dead job ---
#
# The connection dropping only detaches a session, so the job survives
# a reconnect and dies when the resume grace expires with nobody
# having come back. That timing is the whole of decision 2 on the
# issue, and this is what holds it.
reset_jobs()
s3 <- new_session("job-session-3")
with_session(s3, gj <- run_job(function() 1))
# clear the heap so the grace timer is the only thing in it
.g$timers <- list()
.g$job_timer <- NULL

detach_session(s3)
expect_equal(job_status(gj), "running")

resume_session(s3)
run_due_timers(now = as.numeric(Sys.time()) + 600)
expect_equal(job_status(gj), "running")

detach_session(s3)
expect_equal(job_status(gj), "running")
run_due_timers(now = as.numeric(Sys.time()) + 600)
expect_equal(job_status(gj), "cancelled")
expect_true(spawned[[1]]$killed)

# --- shutdown kills everything, and starts nothing ---
#
# The loop is going away. A queued job started here would be an R
# process spawned for work that is about to be killed, which is the
# same mistake as above with nobody left to notice it.
reset_jobs(list(default = list(concurrency = 1L, queue = 4L)))
k1 <- run_job(function() 1, scope = "app")
k2 <- run_job(function() 2, scope = "app")
expect_equal(job_status(k2), "queued")
kill_all_jobs()
expect_equal(job_status(k1), "cancelled")
expect_equal(job_status(k2), "cancelled")
expect_true(spawned[[1]]$killed)
expect_equal(length(spawned), 1L)
expect_equal(length(ls(.g$jobs)), 0L)
expect_null(.g$job_timer)

# --- a spawn that fails is an error, not a job stuck queued ---
reset_jobs()
options(glinty.job_spawner = function(fn, args) stop("no processes left"))
f1 <- run_job(function() 1, scope = "app")
expect_equal(job_status(f1), "error")
expect_true(grepl("no processes left", job_error(f1), fixed = TRUE))
expect_equal(length(ls(.g$jobs)), 0L)

# and the slot it never took goes to the job behind it
reset_jobs(list(default = list(concurrency = 1L, queue = 4L)))
options(glinty.job_spawner = function(fn, args) stop("no processes left"))
f2 <- run_job(function() 1, scope = "app")
f3 <- run_job(function() 2, scope = "app")
expect_equal(job_status(f2), "error")
expect_equal(job_status(f3), "error")

# --- printing a handle ---
reset_jobs()
options(glinty.job_spawner = function(fn, args) {
    list(alive = function() TRUE, result = function() NULL,
         kill = function() invisible(NULL))
})
p1 <- run_job(function() 1, lane = "default", scope = "app")
out <- capture.output(print(p1))
expect_true(grepl("running", out[1], fixed = TRUE))
expect_true(grepl("lane=default", out[1], fixed = TRUE))

# --- the bundled example is a working app ---
#
# The acceptance test on the issue was "a demo app with a slow
# computation button stays responsive in a second tab". The staying
# responsive is what the whole file is about; this is the part a test
# can hold: the example builds, its button starts a job, and its
# rendered output follows the job to completion.
reset_jobs()
options(glinty.job_spawner = fake_spawner)

example <- source(system.file("examples/jobs/app.R", package = "glinty"),
                  local = new.env())$value
expect_true(inherits(example, "glinty_app"))
html <- glinty:::component_to_html(example$ui)
expect_true(grepl('data-g-target="start"', html, fixed = TRUE))

ex_session <- new_session("example")
with_session(ex_session, example$server(ex_session$input, ex_session$output))
flush_reactions()

ui_of <- function(session) {
    msgs <- Filter(function(m) identical(m$id, "jobs"),
                   lapply(session$outgoing, function(m) {
                       jsonlite::fromJSON(m, simplifyVector = FALSE)
                   }))
    if (length(msgs) == 0L) NULL else msgs[[length(msgs)]]$value
}
first_line <- function(tree) {
    if (identical(tree$component, "text")) {
        tree$value
    } else {
        tree$children[[1]]$value
    }
}

expect_equal(first_line(ui_of(ex_session)), "Nothing started yet.")

glinty:::handle_event(ex_session, "start", 1L)
flush_reactions()
expect_equal(length(spawned), 1L)
expect_true(grepl("running", first_line(ui_of(ex_session)), fixed = TRUE))

finishes(spawned[[1]], "8 seconds of work, in pid 999")
job_poll()
flush_reactions()
expect_true(grepl("in pid 999", first_line(ui_of(ex_session)), fixed = TRUE))
session_end(ex_session)

# --- the real thing ---
#
# Everything above drives a fake process. This is the callr seam
# itself: a function handed to an R session that has never seen this
# one, and a value coming back.
options(glinty.job_spawner = NULL)
reset_jobs()

settle <- function(job, timeout = 60) {
    deadline <- Sys.time() + timeout
    while (identical(job_status(job), "running") && Sys.time() < deadline) {
        Sys.sleep(0.05)
        job_poll()
    }
    .g$timers <- list()
    .g$job_timer <- NULL
    job_status(job)
}

real <- run_job(function(x) x * 2, args = list(x = 21), scope = "app")
expect_equal(job_status(real), "running")
expect_equal(settle(real), "done")
expect_equal(job_result(real), 42)

if (at_home()) {
    # An error in the child arrives as a message, not as a hang
    reset_jobs()
    boom <- run_job(function() stop("boom in the child"), scope = "app")
    expect_equal(settle(boom), "error")
    expect_true(grepl("boom in the child", job_error(boom), fixed = TRUE))

    # The documented constraint, as a test: the function runs in a
    # session that has never seen this one, so it sees its arguments
    # and nothing else.
    reset_jobs()
    k <- 5
    closed_over <- run_job(function() k + 1, scope = "app")
    expect_equal(settle(closed_over), "error")
    expect_true(grepl("'k' not found", job_error(closed_over), fixed = TRUE))

    # and the same thing written the way that works
    reset_jobs()
    passed_in <- run_job(function(k) k + 1, args = list(k = 5), scope = "app")
    expect_equal(settle(passed_in), "done")
    expect_equal(job_result(passed_in), 6)

    # A killed job never settles as done, however long anyone waits
    reset_jobs()
    slow <- run_job(function() Sys.sleep(30), scope = "app")
    expect_true(job_cancel(slow))
    expect_equal(job_status(slow), "cancelled")
}

reset_jobs()
