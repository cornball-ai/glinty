% tinyrox says don't edit this manually, but it can't stop you!
\name{job_failure}
\alias{job_failure}
\title{Why a background job failed, in one message}
\usage{
job_failure(e, err_file)
}
\arguments{
\item{e}{the condition callr raised}

\item{err_file}{character path to the child's stderr}
}
\value{
character message
}
\description{
callr reports the remote condition when the child returned an
error, and very little when the child died without returning at all
-- a segfault in a linked library, an out-of-memory kill. stderr is
the only account of that, so its tail is joined on rather than left
in a temp file nobody will think to look for.
}
\keyword{internal}
