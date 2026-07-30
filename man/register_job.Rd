% tinyrox says don't edit this manually, but it can't stop you!
\name{register_job}
\alias{register_job}
\title{Add a job to the in-flight registry}
\usage{
register_job(job)
}
\arguments{
\item{job}{a glinty_job}
}
\value{
invisible(NULL)
}
\description{
The registry holds queued and running jobs and nothing else --
settled jobs drop out of it, so it stays the size of the work
actually in flight rather than growing for the life of the app. The
handle keeps working either way; it reads its own reactive value.
}
\keyword{internal}
