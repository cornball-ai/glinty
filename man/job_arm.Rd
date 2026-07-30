% tinyrox says don't edit this manually, but it can't stop you!
\name{job_arm}
\alias{job_arm}
\title{Arm the completion poller if any work is in flight}
\usage{
job_arm()
}
\value{
invisible(NULL)
}
\description{
One timer for all jobs, re-armed by each sweep and left unarmed
when the registry empties -- so an app that never runs a job pays
nothing, and an app between jobs goes back to sleeping in
socketSelect for as long as its other timers allow.
}
\keyword{internal}
