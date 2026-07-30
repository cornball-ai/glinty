% tinyrox says don't edit this manually, but it can't stop you!
\name{job_spawn}
\alias{job_spawn}
\title{Start a background R process}
\usage{
job_spawn(fn, args)
}
\arguments{
\item{fn}{function to run}

\item{args}{list of arguments}
}
\value{
list(alive, result, kill)
}
\description{
The one seam between glinty and callr. Everything above this line
knows a process only as three functions -- alive(), result(),
kill() -- which is what lets the tests drive completion, failure
and killing by hand instead of waiting on real processes.
}
\keyword{internal}
