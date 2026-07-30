% tinyrox says don't edit this manually, but it can't stop you!
\name{job_start}
\alias{job_start}
\title{Start a queued job now}
\usage{
job_start(job)
}
\arguments{
\item{job}{a glinty_job}
}
\value{
invisible(NULL)
}
\description{
A spawn that fails settles the job as an error rather than leaving
it queued forever: the loop must never hold work it cannot report
on.
}
\keyword{internal}
