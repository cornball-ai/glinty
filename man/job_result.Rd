% tinyrox says don't edit this manually, but it can't stop you!
\name{job_result}
\alias{job_result}
\title{A job's return value, reactively}
\usage{
job_result(job)
}
\arguments{
\item{job}{a glinty_job from run_job()}
}
\value{
the value the function returned, or NULL
}
\description{
NULL until the job is done, and NULL forever if it errored or was
cancelled -- so a job whose function legitimately returns NULL is
told apart by job_status(), not by this.
}
\examples{
\dontrun{
output$answer <- render_text(function() job_result(job))
}
}
