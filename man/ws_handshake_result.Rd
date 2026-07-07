% tinyrox says don't edit this manually, but it can't stop you!
\name{ws_handshake_result}
\alias{ws_handshake_result}
\title{Validate an upgrade request and build the response}
\usage{
ws_handshake_result(req)
}
\arguments{
\item{req}{a parsed request from parse_http_head()}
}
\value{
list(ok = logical, response = raw)
}
\description{
Pure function: returns ok plus the exact bytes to write, so the
whole handshake is testable without sockets. On ok the connection
is promoted to a WebSocket; otherwise it is closed after writing.
}
\keyword{internal}
