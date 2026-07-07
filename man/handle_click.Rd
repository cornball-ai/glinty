% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_click}
\alias{handle_click}
\title{Process a button click for a session}
\usage{
handle_click(session, id)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}
}
\description{
Click counters follow action-button semantics: the input starts at
NULL (treated as 0) and each click increments it, so every click
invalidates dependents even though the "value" is monotonic.
}
\keyword{internal}
