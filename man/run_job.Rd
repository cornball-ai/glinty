% tinyrox says don't edit this manually, but it can't stop you!
\name{run_job}
\alias{run_job}
\title{Run a function in a background R process}
\usage{
run_job(fn, args = list(), lane = "default", scope = c("session", "app"))
}
\arguments{
\item{fn}{a function to run in the background; self-contained, as
above}

\item{args}{list of arguments to call it with}

\item{lane}{character lane name; must be one the app configured}

\item{scope}{"session" (the default) ties the job to the session
that started it: it survives a dropped connection and a resume,
and is killed if the resume grace expires without anyone coming
back. "app" outlives every session and stops only with the app.}
}
\value{
a glinty_job handle. Read it with job_status(),
  job_result() and job_error(); stop it with job_cancel().
}
\description{
The function is handed to a fresh R session, which is what keeps
the event loop free: every other session stays responsive while it
runs. Completion arrives reactively -- `job_status()` and
`job_result()` are reactive reads, so an output that calls one
re-renders when the job settles, with no polling in app code.
}
\details{
**The function must be self-contained.** It runs in a session that
has never seen the calling environment, so it can use its arguments
and packages it loads itself, and nothing else:

\preformatted{
k <- 5
run_job(function() k + 1)              # fails: object 'k' not found
run_job(function(k) k + 1, list(k = 5))  # works
}

Jobs run in a named lane, and the app sizes each lane (see
`run_app(job_lanes =)`). With a free slot the job starts at once;
under the lane's queue depth it waits; past that it is refused, and
the refusal comes back as a handle whose status is `"refused"`
rather than as a silent drop or a thirty-deep wait.

}
\examples{
\dontrun{
output$answer <- render_text(function() {
    switch(job_status(job),
           running = "working...",
           done = job_result(job),
           error = paste("failed:", job_error(job)),
           refused = paste("busy:", job_error(job)),
           job_status(job))
})
}
}
