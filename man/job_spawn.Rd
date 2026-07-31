% tinyrox says don't edit this manually, but it can't stop you!
\name{job_spawn}
\alias{job_spawn}
\title{Start a background R process}
\usage{
job_spawn(fn, args, progress_file = NULL)
}
\arguments{
\item{fn}{function to run}

\item{args}{list of arguments}

\item{progress_file}{character path the child reports progress to,
passed in the environment so it costs the job's function no
argument of its own}
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
