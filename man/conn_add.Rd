% tinyrox says don't edit this manually, but it can't stop you!
\name{conn_add}
\alias{conn_add}
\title{Register a newly accepted connection}
\usage{
conn_add(con, state = "http_pending")
}
\arguments{
\item{con}{a socket connection (non-blocking, binary)}

\item{state}{character initial state ("http_pending")}
}
\value{
character connection key
}
\description{
Register a newly accepted connection
}
\keyword{internal}
