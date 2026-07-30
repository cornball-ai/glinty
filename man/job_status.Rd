% tinyrox says don't edit this manually, but it can't stop you!
\name{job_status}
\alias{job_status}
\title{A job's status, reactively}
\usage{
job_status(job)
}
\arguments{
\item{job}{a glinty_job from run_job()}
}
\value{
character status
}
\description{
One of "queued", "running", "done", "error", "cancelled" or
"refused". Reading it inside a renderer or observer registers a
dependency, so that output re-renders when the job settles.
}
\examples{
\dontrun{
output$state <- render_text(function() job_status(job))
}
}
