% tinyrox says don't edit this manually, but it can't stop you!
\name{session_end}
\alias{session_end}
\title{End a session}
\usage{
session_end(session)
}
\arguments{
\item{session}{a glinty_session}
}
\value{
invisible(NULL)
}
\description{
Destroys every observer created under the session, fires on_ended
callbacks, and removes the session from the registry. Idempotent.
}
\keyword{internal}
