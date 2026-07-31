% tinyrox says don't edit this manually, but it can't stop you!
\name{job_report_progress}
\alias{job_report_progress}
\title{Write this job's progress where the server will read it}
\usage{
job_report_progress(value = NULL, detail = NULL, message = NULL, add = FALSE)
}
\arguments{
\item{value}{numeric fraction, or NULL to leave it}

\item{detail}{character secondary line, or NULL}

\item{message}{character headline, or NULL}

\item{add}{logical treat value as an increment}
}
\value{
TRUE if this process is a job and the write was attempted
}
\description{
Overwritten rather than appended: progress is a level, not a
stream. Only the newest value means anything, and a file that grows
with every update makes each poll cost more than the one before.
}
\keyword{internal}
