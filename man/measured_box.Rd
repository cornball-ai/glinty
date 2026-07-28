% tinyrox says don't edit this manually, but it can't stop you!
\name{measured_box}
\alias{measured_box}
\title{Read an output's client-reported box, reactively}
\usage{
measured_box(session, id)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character output ID}
}
\value{
list(width, height, dpr), or NULL before any report
}
\description{
Read an output's client-reported box, reactively
}
\keyword{internal}
