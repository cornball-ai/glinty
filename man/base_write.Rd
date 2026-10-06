% tinyrox says don't edit this manually, but it can't stop you!
\name{base_write}
\alias{base_write}
\title{Write bytes to a base transport connection}
\usage{
base_write(entry, bytes)
}
\arguments{
\item{entry}{registry entry}

\item{bytes}{raw vector}
}
\value{
logical success
}
\description{
A failed write surfaces from R as a warning, which here means
FALSE; the caller decides whether that marks the connection dead.
}
\keyword{internal}
