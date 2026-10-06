% tinyrox says don't edit this manually, but it can't stop you!
\name{output_visible}
\alias{output_visible}
\title{Is this output's panel open?}
\usage{
output_visible(session, id)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character output id}
}
\value{
logical
}
\description{
Reads the selection input of every tabset enclosing the output,
inside the output's own reactive context, which is what re-runs
the renderer when the panel opens. An output the map does not
know, or a session with no map, is visible. A tabset whose
selection is NULL (unseeded, never reported) hides nothing: a
guess that suspends is worse than a render nobody sees.
}
\keyword{internal}
