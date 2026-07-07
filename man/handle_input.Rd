% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_input}
\alias{handle_input}
\title{Process an input change for a session}
\usage{
handle_input(session, id, value)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{value}{the new value}
}
\description{
Creates a reactive_val for new inputs or updates existing ones.
Does not flush; the dispatch layer flushes after handling.
}
\keyword{internal}
