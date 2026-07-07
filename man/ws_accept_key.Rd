% tinyrox says don't edit this manually, but it can't stop you!
\name{ws_accept_key}
\alias{ws_accept_key}
\title{Compute the Sec-WebSocket-Accept value}
\usage{
ws_accept_key(key)
}
\arguments{
\item{key}{character Sec-WebSocket-Key from the client}
}
\value{
character accept key
}
\description{
base64 of the SHA-1 digest of the client key concatenated with the
RFC 6455 GUID.
}
\keyword{internal}
