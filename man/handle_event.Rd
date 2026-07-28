% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_event}
\alias{handle_event}
\title{Process a discrete event for a session}
\usage{
handle_event(session, id)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}
}
\description{
Event counters follow action-button semantics: the input starts at
NULL (treated as 0) and each event increments it, so every press
invalidates dependents even though the "value" is monotonic.
}
\keyword{internal}
