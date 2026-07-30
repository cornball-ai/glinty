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
Destroys every observer created under the session, kills the
background jobs it started, fires on_ended callbacks, and removes
the session from the registry. Idempotent.
}
\details{
This is the one place session-scoped jobs are killed, which is what
gives them their stated lifetime: a dropped connection detaches a
session rather than ending it, so a job survives a reconnect and
dies only when the resume grace expires with nobody having come
back.

}
\keyword{internal}
