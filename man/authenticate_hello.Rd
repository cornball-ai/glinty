% tinyrox says don't edit this manually, but it can't stop you!
\name{authenticate_hello}
\alias{authenticate_hello}
\title{Run the configured verifier against a hello}
\usage{
authenticate_hello(auth, msg, req = NULL)
}
\arguments{
\item{auth}{a function(token) or function(token, req), or NULL}

\item{msg}{decoded hello message}

\item{req}{the parsed HTTP request that upgraded this connection
(method, path, query, headers), or NULL when none survives}
}
\value{
list(ok, principal)
}
\description{
No verifier means no gate: everything is accepted with a NULL
principal, which is what keeps localhost development frictionless.
A verifier that errors refuses, the same as returning NULL --
failing open on an exception would make a bug in the verifier a
bypass of it.
}
\keyword{internal}
