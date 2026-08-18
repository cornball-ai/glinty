% tinyrox says don't edit this manually, but it can't stop you!
\name{dispatch_client_message}
\alias{dispatch_client_message}
\title{Dispatch one client message to a session}
\usage{
dispatch_client_message(session, txt)
}
\arguments{
\item{session}{a glinty_session}

\item{txt}{character JSON from one WebSocket text frame}
}
\value{
invisible(NULL)
}
\description{
Parses the JSON text frame and routes by type: hello records the
client's declared capabilities, input applies a single input
change, event bumps an event counter. hello no longer carries
input values -- under v3 the server built the tree, so it seeded
the defaults itself before the client ever connected.
Malformed or unknown messages queue an error message instead of
raising. Flushes before returning, so each frame is processed to
quiescence in wire order (see the comment at the flush).
}
\keyword{internal}
