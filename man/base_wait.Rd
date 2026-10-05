% tinyrox says don't edit this manually, but it can't stop you!
\name{base_wait}
\alias{base_wait}
\title{One wait on the base transport}
\usage{
base_wait(handlers, timeout)
}
\arguments{
\item{handlers}{the handler list}

\item{timeout}{numeric seconds}
}
\value{
invisible(NULL)
}
\description{
Sleeps in socketSelect() for up to `timeout` seconds, accepts what
arrived on the listener, and feeds each readable connection's bytes
to its state machine.
}
\keyword{internal}
