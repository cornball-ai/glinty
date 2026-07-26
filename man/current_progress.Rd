% tinyrox says don't edit this manually, but it can't stop you!
\name{current_progress}
\alias{current_progress}
\title{The innermost open progress handle}
\usage{
current_progress()
}
\value{
a progress handle, or NULL when none is open
}
\description{
The stack is global rather than session-scoped because the event
loop is single-threaded: only one with_progress() can be running
at any moment, so the top of the stack is unambiguous.
}
\keyword{internal}
