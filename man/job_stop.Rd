% tinyrox says don't edit this manually, but it can't stop you!
\name{job_stop}
\alias{job_stop}
\title{Stop one job without filling the slot it frees}
\usage{
job_stop(job)
}
\arguments{
\item{job}{a glinty_job}
}
\value{
TRUE if this call stopped it, FALSE if it was already over
}
\description{
The pump is separated out because cancelling *several* jobs must
not start work in between. Killing a session's running job frees a
slot; pumping there would start that same session's queued job --
spawning an R process, and its startup side effects, for a session
that has already ended, only to kill it a moment later. A batch
cancels first and pumps once, or not at all when the app is going
down.
}
\keyword{internal}
