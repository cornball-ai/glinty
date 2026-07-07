% tinyrox says don't edit this manually, but it can't stop you!
\name{new_session}
\alias{new_session}
\title{Create a session}
\usage{
new_session(id, send_fn = NULL)
}
\arguments{
\item{id}{character session ID (server-generated)}

\item{send_fn}{function(msg) used by drain_session() to write a
message to the transport; NULL buffers messages for tests}
}
\value{
A glinty_session environment
}
\description{
A session holds all per-connection reactive state: the input
environment, the output registry, queued outgoing messages, and the
observers created while this session was current. One browser tab
equals one session.
}
\keyword{internal}
