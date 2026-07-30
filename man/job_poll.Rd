% tinyrox says don't edit this manually, but it can't stop you!
\name{job_poll}
\alias{job_poll}
\title{Sweep finished jobs, then fill the slots they freed}
\usage{
job_poll()
}
\value{
invisible(NULL)
}
\description{
Runs from the event loop's timer heap, which is the whole point:
no second wakeup mechanism, no busy loop, and the sweep stops as
soon as nothing is in flight.
}
\keyword{internal}
