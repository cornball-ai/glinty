% tinyrox says don't edit this manually, but it can't stop you!
\name{drain_socket}
\alias{drain_socket}
\title{Read everything currently buffered on a non-blocking socket}
\usage{
drain_socket(con)
}
\arguments{
\item{con}{a socket connection}
}
\value{
raw vector (length 0 means EOF if select said readable)
}
\description{
Read everything currently buffered on a non-blocking socket
}
\keyword{internal}
