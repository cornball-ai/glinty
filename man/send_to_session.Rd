% tinyrox says don't edit this manually, but it can't stop you!
\name{send_to_session}
\alias{send_to_session}
\title{Send a text frame to a session's WebSocket}
\usage{
send_to_session(session_id, text)
}
\arguments{
\item{session_id}{character session id}

\item{text}{character message (one JSON object)}
}
\value{
logical success, invisibly
}
\description{
Immediate write through the transport; the kernel socket buffer is
the queue. There is no concurrent writer in a single-threaded
process, and partial-write stalls are bounded by the connection
timeout. A failed write marks the connection dead; the actual close
happens at the top of the next loop iteration.
}
\keyword{internal}
