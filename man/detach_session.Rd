% tinyrox says don't edit this manually, but it can't stop you!
\name{detach_session}
\alias{detach_session}
\title{Detach a session from its transport}
\usage{
detach_session(session)
}
\arguments{
\item{session}{a glinty_session}
}
\value{
invisible(NULL)
}
\description{
Called when the WebSocket drops. Observers and timers stay alive;
outgoing messages buffer (capped); a grace timer ends the session
for real if nobody resumes in time. Idempotent.
}
\keyword{internal}
