% tinyrox says don't edit this manually, but it can't stop you!
\name{lane_count}
\alias{lane_count}
\title{One lane setting, as a whole number}
\usage{
lane_count(x, lane, field, min)
}
\arguments{
\item{x}{the supplied value}

\item{lane}{character lane name, for the message}

\item{field}{character field name, for the message}

\item{min}{integer smallest value that means anything}
}
\value{
integer
}
\description{
Nothing is coerced. `as.integer()` would take `2.5` as 2 and `"2"`
as 2, and a lane running at a number its author did not write is
worse than one that refused to start: the app comes up, behaves
unlike the settings on the screen, and nothing says so.
}
\details{
The ceiling is there for the same reason. `as.integer(3e9)` is
`NA`, and a lane whose concurrency is `NA` does not fail here --
it fails at the first `run_job()`, where `lane_running(lane) < NA`
is not a comparison anyone can act on.

}
\keyword{internal}
