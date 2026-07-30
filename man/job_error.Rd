% tinyrox says don't edit this manually, but it can't stop you!
\name{job_error}
\alias{job_error}
\title{Why a job failed or was refused, reactively}
\usage{
job_error(job)
}
\arguments{
\item{job}{a glinty_job from run_job()}
}
\value{
character message, or NULL
}
\description{
The child's error message for an "error", the lane and its
occupancy for a "refused", NULL otherwise. Both come back as text
for the same reason: an app that has to show the user why nothing
happened should not need two code paths to say it.
}
\examples{
\dontrun{
output$why <- render_text(function() job_error(job))
}
}
