% tinyrox says don't edit this manually, but it can't stop you!
\name{scoped_id}
\alias{scoped_id}
\title{A namespaced id for a session helper}
\usage{
scoped_id(session, id)
}
\arguments{
\item{session}{a session, scoped or not}

\item{id}{character id}
}
\value{
character
}
\description{
The id a helper such as download_handler() was given, prefixed
when the session is a scoped one and left alone otherwise.
}
\keyword{internal}
