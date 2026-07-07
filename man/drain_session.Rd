% tinyrox says don't edit this manually, but it can't stop you!
\name{drain_session}
\alias{drain_session}
\title{Drain a session's outgoing message queue}
\usage{
drain_session(session)
}
\arguments{
\item{session}{a glinty_session}
}
\value{
list of character JSON messages, invisibly
}
\description{
Sends each queued message through the session's send_fn (if any)
and returns the drained messages.
}
\keyword{internal}
