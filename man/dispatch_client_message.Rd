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
Parses the JSON text frame and routes by type: init seeds the
input environment with the client's harvested DOM values, input
applies a single input change, click bumps a click counter.
Malformed or unknown messages queue an error message instead of
raising. Does not flush; the caller flushes after dispatch.
}
\keyword{internal}
