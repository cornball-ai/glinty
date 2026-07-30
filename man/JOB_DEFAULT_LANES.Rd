% tinyrox says don't edit this manually, but it can't stop you!
\docType{data}
\name{JOB_DEFAULT_LANES}
\alias{JOB_DEFAULT_LANES}
\title{The lane table an app gets when it asks for nothing}
\format{
An object of class \code{list} of length 1.
}
\usage{
JOB_DEFAULT_LANES
}
\description{
Two at a time with eight waiting: enough that a couple of tabs each
doing something slow do not queue behind each other, small enough
that a runaway loop of run_job() calls is refused rather than
forking a hundred R processes.
}
\keyword{internal}
