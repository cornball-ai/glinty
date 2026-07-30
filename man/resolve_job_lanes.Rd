% tinyrox says don't edit this manually, but it can't stop you!
\name{resolve_job_lanes}
\alias{resolve_job_lanes}
\title{Validate an app's lane settings}
\usage{
resolve_job_lanes(job_lanes = NULL)
}
\arguments{
\item{job_lanes}{named list of list(concurrency =, queue =), or NULL}
}
\value{
the resolved lane table
}
\description{
Lanes merge over the built-in default, so an app naming only a
`gpu` lane keeps a `default` lane for everything else. Both fields
are required per lane: a queue depth inherited from somewhere else
is exactly the kind of number nobody would be able to explain
afterwards.
}
\keyword{internal}
