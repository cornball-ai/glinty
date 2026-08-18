% tinyrox says don't edit this manually, but it can't stop you!
\name{call_verifier}
\alias{call_verifier}
\title{Call a verifier with as much context as it accepts}
\usage{
call_verifier(auth, token, req)
}
\arguments{
\item{auth}{the configured verifier function}

\item{token}{character token from the hello, or NULL}

\item{req}{the parsed upgrade request, or NULL}
}
\value{
whatever the verifier returns
}
\description{
A one-argument verifier gets the token, as always. A verifier
declaring a second parameter also gets the HTTP request that opened
the connection (method, path, query, headers with lower-cased
names). That request is how an HttpOnly-cookie session can
authenticate at all: the page's script cannot read the cookie to
put it in the hello, but the browser attached it to the upgrade
request's Cookie header.
}
\keyword{internal}
