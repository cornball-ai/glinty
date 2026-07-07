% tinyrox says don't edit this manually, but it can't stop you!
\name{mark_dead}
\alias{mark_dead}
\title{Mark a connection dead without closing it yet}
\usage{
mark_dead(key)
}
\arguments{
\item{key}{character connection key}
}
\value{
invisible(NULL)
}
\description{
Used by the write path: closing mid-flush would mutate the
registry under the reactive core's feet, so the close is deferred
to the top of the next loop iteration.
}
\keyword{internal}
