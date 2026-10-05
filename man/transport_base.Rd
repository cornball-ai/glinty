% tinyrox says don't edit this manually, but it can't stop you!
\name{transport_base}
\alias{transport_base}
\title{The base R socket transport}
\usage{
transport_base()
}
\value{
a transport list
}
\description{
serverSocket() takes no bind address, so this listens on every
interface. HTTP parsing, the WebSocket handshake and framing all
happen in R, on the bytes each non-blocking connection has buffered.
}
\keyword{internal}
