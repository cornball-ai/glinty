% tinyrox says don't edit this manually, but it can't stop you!
\name{conn_close}
\alias{conn_close}
\title{Close a connection and clean up}
\usage{
conn_close(key, notify, handlers, code = 1000L)
}
\arguments{
\item{key}{character connection key}

\item{notify}{logical whether to fire on_close}

\item{handlers}{the event-loop handler list}

\item{code}{integer close code for the goodbye frame}
}
\value{
invisible(NULL)
}
\description{
Idempotent. Sends a best-effort close frame on open WebSockets,
closes the socket, removes registry entries, and (when notify is
TRUE and a session was attached) fires the on_close handler so the
reactive core tears the session down.
}
\keyword{internal}
