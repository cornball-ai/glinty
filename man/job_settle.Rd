% tinyrox says don't edit this manually, but it can't stop you!
\name{job_settle}
\alias{job_settle}
\title{Settle a job and free its slot}
\usage{
job_settle(job, status, result = NULL, error = NULL)
}
\arguments{
\item{job}{a glinty_job}

\item{status}{one of "done", "error", "cancelled", "refused"}

\item{result}{the value, for "done"}

\item{error}{character message, for "error" and "refused"}
}
\value{
invisible(NULL)
}
\description{
Settle a job and free its slot
}
\keyword{internal}
