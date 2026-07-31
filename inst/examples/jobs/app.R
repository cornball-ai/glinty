library(glinty)

# What this example demonstrates is what does not happen. While jobs
# run, the clock keeps ticking, the buttons keep responding, and a
# second browser tab is unaffected -- because the work is in other R
# processes. The same eight seconds spent inside an observer would
# freeze all of that, for every connected session.
#
# run_example("jobs") runs it with the built-in lane: two at a time,
# eight waiting. To watch a refusal without pressing the button
# eleven times, run it with a tighter one:
#
#   app_obj <- source(system.file("examples/jobs/app.R", package = "glinty"))$value
#   run_app(app_obj,
#           job_lanes = list(default = list(concurrency = 1, queue = 1)))

app(
    ui = page(
        heading("Background jobs", level = 1L),
        txt(paste("Start a few, watch the clock, and open a second tab.",
                  "Everything stays live while the work runs elsewhere.")),
        row(
            button("start", "Run 8 seconds of work"),
            button("cancel", "Cancel the unfinished ones", variant = "ghost"),
            gap = 8L
        ),
        panel(ui_output("jobs"), variant = "card", title = "Jobs"),
        divider(),
        text_output("clock"),
        title = "glinty background jobs"
    ),
    server = function(input, output) {
        jobs <- reactive_val(list())

        observe_event(input$start, function() {
            # Self-contained: the child sees its arguments and nothing
            # else, so the duration goes in as one, and the pid comes
            # back as proof of where it ran.
            #
            # set_progress() is the same call an in-process operation
            # would make. Over here there is no bar and no session, so
            # it writes where the server is reading instead.
            job <- run_job(function(seconds) {
                for (i in seq_len(seconds)) {
                    glinty::set_progress(i / seconds,
                                         detail = paste("second", i))
                    Sys.sleep(1)
                }
                sprintf("%d seconds of work, in pid %d", seconds, Sys.getpid())
            }, args = list(seconds = 8L))
            jobs(c(isolate(jobs()), list(job)))
        })

        observe_event(input$cancel, function() {
            for (job in isolate(jobs())) {
                job_cancel(job)
            }
        })

        output$jobs <- render_ui(function() {
            all <- jobs()
            if (length(all) == 0L) {
                return(txt("Nothing started yet."))
            }
            lines <- lapply(seq_along(all), function(i) {
                job <- all[[i]]
                status <- job_status(job)
                reported <- job_progress(job)
                detail <- if (identical(status, "done")) {
                    job_result(job)
                } else if (identical(status, "running") &&
                               !is.null(reported)) {
                    sprintf("%d%%, %s", round(reported$value * 100),
                            reported$detail)
                } else {
                    job_error(job)
                }
                txt(sprintf("%d. %s%s", i, status,
                            if (is.null(detail)) "" else paste0(" -- ", detail)),
                    variant = if (status %in% c("error", "refused")) {
                        "strong"
                    } else {
                        "normal"
                    })
            })
            do.call(column, c(lines, list(gap = 4L)))
        })

        # The proof: this keeps counting for the whole eight seconds.
        output$clock <- render_text(function() {
            invalidate_later(1000)
            sprintf("pid %d is at %s", Sys.getpid(),
                    format(Sys.time(), "%H:%M:%S"))
        })
    }
)
