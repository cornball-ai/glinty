% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_measure}
\alias{handle_measure}
\title{Record a client measurement for one output}
\usage{
handle_measure(session, msg)
}
\arguments{
\item{session}{a glinty_session}

\item{msg}{decoded measure message}
}
\value{
invisible(NULL)
}
\description{
Width and height arrive in logical pixels, dpr as physical pixels
per logical one (absent means 1). Last write wins, per id, into
session state -- element state on the client may come and go with
rebuilds, but the session's idea of "how big is this output" only
changes when a client reports a new box. A measurement for an id
with no renderer yet is stored and harmless: dynamic UI races
layout, and the output it names may be about to exist.
}
\details{
Stored as a reactive value, so a renderer that read it re-renders
exactly when a new box arrives.

}
\keyword{internal}
