% tinyrox says don't edit this manually, but it can't stop you!
\name{resume_session}
\alias{resume_session}
\title{Re-attach a detached session after a resume handshake}
\usage{
resume_session(session)
}
\arguments{
\item{session}{a glinty_session}
}
\value{
invisible(NULL)
}
\description{
Cancels the grace timer and queues, in order: a welcome with
resumed = TRUE, the last message of every output (current state,
no re-render), then whatever non-output messages buffered while
detached. The client keeps its live DOM on a resumed welcome, so
the tree riding along is ignored there.
}
\keyword{internal}
