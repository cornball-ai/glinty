% tinyrox says don't edit this manually, but it can't stop you!
\name{make_input_proxy}
\alias{make_input_proxy}
\title{Create an input proxy for a session}
\usage{
make_input_proxy(session)
}
\arguments{
\item{session}{a glinty_session}
}
\value{
a glinty_input proxy
}
\description{
Wraps the session's input environment so that accessing an unknown
input auto-creates a reactive_val initialized to NULL. This prevents
errors when server code reads inputs before any events arrive.
}
\keyword{internal}
