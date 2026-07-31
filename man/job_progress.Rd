% tinyrox says don't edit this manually, but it can't stop you!
\name{job_progress}
\alias{job_progress}
\title{What a job last reported, reactively}
\usage{
job_progress(job)
}
\arguments{
\item{job}{a glinty_job from run_job()}
}
\value{
list(value, message, detail), or NULL
}
\description{
NULL until the job reports something. Inside the job, report with
the same `set_progress()` and `inc_progress()` an in-process
operation would use -- they notice they are running in a background
process and write where the server is reading:
}
\details{
\preformatted{
job <- run_job(function(n) {
for (i in seq_len(n)) {
glinty::set_progress(i / n, detail = paste("step", i))
one_step(i)
}
}, args = list(n = 10))

output$bar <- render_text(function() {
p <- job_progress(job)
if (is.null(p)) "starting" else paste0(round(p$value * 100), "\%")
})
}

Updates arrive when the poller next runs, so the resolution is
`getOption("glinty.job_poll", 0.25)` seconds rather than every call
the job makes.

}
\examples{
\dontrun{
output$pct <- render_text(function() job_progress(job)$value)
}
}
