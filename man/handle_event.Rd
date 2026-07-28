% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_event}
\alias{handle_event}
\title{Process a discrete event for a session}
\usage{
handle_event(session, id, value = NULL)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{value}{the button's value, or NULL for a counting button}
}
\description{
Event counters follow action-button semantics: the input starts at
NULL (treated as 0) and each event increments it, so every press
invalidates dependents even though the "value" is monotonic.
}
\details{
A button carrying a `value` sets that instead of counting, so one
handler can serve a list of rows and read which row was pressed.
Pressing the same row twice still invalidates -- reactive_val()
writes unconditionally -- so this keeps event semantics rather
than quietly becoming an input that ignores repeats.

}
\keyword{internal}
