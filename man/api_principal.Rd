% tinyrox says don't edit this manually, but it can't stop you!
\name{api_principal}
\alias{api_principal}
\title{Resolve the caller of an api request}
\usage{
api_principal(req, auth)
}
\arguments{
\item{req}{parsed request}

\item{auth}{the configured verifier, or NULL}
}
\value{
whatever the verifier returned, or NULL
}
\description{
Runs the same verifier that gates WebSocket sessions, fed the
Authorization Bearer token. A verifier declaring a second
parameter also receives the request itself, so a session kept in
an HttpOnly cookie is visible to it. A verifier that errors
yields NULL -- the request proceeds unauthenticated and a
default-deny router refuses it, which fails closed without
letting a verifier bug take down unauthenticated routes like a
ping.
}
\keyword{internal}
