# A job reporting progress from another process.
#
# The child cannot call set_progress() the way an in-process operation
# does -- there is no bar, no session and no event loop over there. So
# the same call writes a file the server reads on its next poll, and
# which of the two happens is decided by an environment variable the
# spawner sets. One verb, two places: instrumented code moves into a
# job without being rewritten.

.g <- getFromNamespace(".globals", "glinty")

job_report_progress <- glinty:::job_report_progress
job_read_progress <- glinty:::job_read_progress
job_progress_path <- glinty:::job_progress_path
job_poll <- glinty:::job_poll

reset_progress <- function() {
    .g$jobs <- new.env(parent = emptyenv())
    .g$job_queues <- list()
    .g$job_lanes <- glinty:::JOB_DEFAULT_LANES
    .g$job_timer <- NULL
    .g$timers <- list()
    .g$pending_flush <- list()
    .g$current_session <- NULL
    .g$current_context <- NULL
    .g$job_progress_last <- NULL
    .g$progress <- list()
    Sys.unsetenv("GLINTY_JOB_PROGRESS")
    spawned <<- list()
}

spawned <- list()
fake_spawner <- function(fn, args, progress_file = NULL) {
    proc <- new.env(parent = emptyenv())
    proc$alive <- TRUE
    proc$value <- NULL
    proc$progress_file <- progress_file
    spawned[[length(spawned) + 1L]] <<- proc
    list(alive = function() proc$alive,
         result = function() proc$value,
         kill = function() proc$alive <- FALSE)
}

# --- outside a job, nothing changes ---
reset_progress()
expect_null(job_progress_path())
expect_false(job_report_progress(0.5))
# and the in-process verbs still do nothing outside a with_progress(),
# which is what lets instrumented code run in a plain script
expect_silent(set_progress(0.5))
expect_silent(inc_progress(0.1))

# --- inside a job, the same verbs write the file ---
file <- tempfile(fileext = ".json")
Sys.setenv(GLINTY_JOB_PROGRESS = file)
expect_equal(job_progress_path(), file)

set_progress(0.25, detail = "quarter")
written <- jsonlite::fromJSON(readLines(file, warn = FALSE))
expect_equal(written$value, 0.25)
expect_equal(written$detail, "quarter")

# inc_progress adds to what this process last reported, since the
# server's copy is not readable from here
inc_progress(0.25, detail = "half")
written <- jsonlite::fromJSON(readLines(file, warn = FALSE))
expect_equal(written$value, 0.5)
expect_equal(written$detail, "half")

# a message set once stays set
set_progress(0.75)
written <- jsonlite::fromJSON(readLines(file, warn = FALSE))
expect_equal(written$detail, "half")
expect_equal(written$value, 0.75)

# out-of-range values clamp rather than escaping the bar
set_progress(5)
expect_equal(jsonlite::fromJSON(readLines(file, warn = FALSE))$value, 1)
set_progress(-1)
expect_equal(jsonlite::fromJSON(readLines(file, warn = FALSE))$value, 0)

# one line, not a growing log: progress is a level, and a file that
# grew with every update would make each poll cost more than the last
for (i in 1:20) {
    set_progress(i / 20)
}
expect_equal(length(readLines(file, warn = FALSE)), 1L)

# a file that cannot be written does not take the job down with it
Sys.setenv(GLINTY_JOB_PROGRESS = file.path(tempdir(), "no", "such", "dir",
                                           "p.json"))
expect_silent(set_progress(0.5))

Sys.unsetenv("GLINTY_JOB_PROGRESS")
unlink(file)

# --- the server side reads it ---
reset_progress()
job <- new.env(parent = emptyenv())
job$progress_file <- tempfile(fileext = ".json")
expect_null(job_read_progress(job))

writeLines('{"value":0.4,"message":"m","detail":"d"}', job$progress_file)
got <- job_read_progress(job)
expect_equal(got$value, 0.4)
expect_equal(got$detail, "d")

# a read landing mid-write sees a truncated line; ignoring it costs
# one update, and the next poll has the whole thing
writeLines('{"value":0.4,"messa', job$progress_file)
expect_null(job_read_progress(job))
unlink(job$progress_file)
expect_null(job_read_progress(job))

# --- a running job's progress reaches the handle, reactively ---
reset_progress()
options(glinty.job_spawner = fake_spawner)

running <- run_job(function() 1, scope = "app")
expect_null(job_progress(running))
# the spawner was handed a path, which is how the child finds it
expect_true(is.character(spawned[[1]]$progress_file))
expect_equal(spawned[[1]]$progress_file, running$progress_file)

seen <- list()
# c(list(), list(x)), not seen[[n + 1]] <- x: assigning NULL to a list
# element deletes it, so the first run would record nothing and every
# count below would be off by one.
observe(function() seen <<- c(seen, list(job_progress(running))))
expect_equal(length(seen), 1L)

writeLines('{"value":0.3,"message":"working","detail":"step 1"}',
           running$progress_file)
job_poll()
flush_reactions()
expect_equal(job_progress(running)$value, 0.3)
expect_equal(job_progress(running)$message, "working")
expect_equal(length(seen), 2L)

# an unchanged file does not invalidate anything: a bar redrawn four
# times a second because nothing happened is worse than no bar
job_poll()
flush_reactions()
expect_equal(length(seen), 2L)

writeLines('{"value":0.6,"message":"working","detail":"step 2"}',
           running$progress_file)
job_poll()
flush_reactions()
expect_equal(length(seen), 3L)
expect_equal(job_progress(running)$value, 0.6)

# --- the last report survives the job finishing ---
#
# The file is deleted when the job settles, and a job that reports and
# then finishes in the same breath would otherwise lose its final
# update between one poll and the next.
writeLines('{"value":1,"message":"done","detail":"finished"}',
           running$progress_file)
kept <- running$progress_file
spawned[[1]]$value <- "result"
spawned[[1]]$alive <- FALSE
job_poll()
flush_reactions()
expect_equal(job_status(running), "done")
expect_equal(job_progress(running)$value, 1)
expect_equal(job_progress(running)$detail, "finished")
# and the file is gone rather than left in tempdir for the session
expect_false(file.exists(kept))

# a cancelled job cleans up too
reset_progress()
options(glinty.job_spawner = fake_spawner)
cancelled <- run_job(function() 1, scope = "app")
path <- cancelled$progress_file
expect_true(file.create(path))
job_cancel(cancelled)
expect_false(file.exists(path))

expect_error(job_progress("not a job"))

# --- and for real, across a process boundary ---
options(glinty.job_spawner = NULL)
reset_progress()

real <- run_job(function(n) {
    for (i in seq_len(n)) {
        glinty::set_progress(i / n, detail = paste("step", i))
        Sys.sleep(0.1)
    }
    "finished"
}, args = list(n = 6L), scope = "app")

# Only reads taken while the job is still running count. Collecting
# every read would let this pass on a job that finished before the
# first poll, where the value came from the settle path and nothing
# was proven about watching work in flight.
deadline <- Sys.time() + 60
mid <- numeric(0)
while (identical(job_status(real), "running") && Sys.time() < deadline) {
    Sys.sleep(0.02)
    job_poll()
    if (identical(job_status(real), "running")) {
        reported <- job_progress(real)
        if (!is.null(reported)) {
            mid <- c(mid, reported$value)
        }
    }
}
.g$timers <- list()
.g$job_timer <- NULL

expect_equal(job_status(real), "done")
expect_equal(job_result(real), "finished")
# the environment variable reached the child, the child found its own
# file, and the server read it while the work was still going
expect_true(length(mid) > 0L)
expect_true(all(mid > 0 & mid <= 1))
expect_true(min(mid) < 1)
expect_equal(job_progress(real)$value, 1)
expect_true(grepl("^step ", job_progress(real)$detail))

reset_progress()
