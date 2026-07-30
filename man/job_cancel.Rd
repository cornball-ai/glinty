% tinyrox says don't edit this manually, but it can't stop you!
\name{job_cancel}
\alias{job_cancel}
\title{Stop a job}
\usage{
job_cancel(job)
}
\arguments{
\item{job}{a glinty_job from run_job()}
}
\value{
TRUE if this call stopped it, FALSE if it was already over
}
\description{
Kills the process if it is running, drops it from its lane's queue
if it has not started, and does nothing to a job that has already
settled.
}
\examples{
\dontrun{
observe_event(input$stop, function() job_cancel(job))
}
}
