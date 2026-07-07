% tinyrox says don't edit this manually, but it can't stop you!
\name{ws_fail}
\alias{ws_fail}
\title{Fail a WebSocket connection}
\usage{
ws_fail(key, code, handlers)
}
\arguments{
\item{key}{character connection key}

\item{code}{integer close code}

\item{handlers}{the handler list}
}
\value{
invisible(NULL)
}
\description{
Best-effort close frame with the protocol error code, then close
and notify.
}
\keyword{internal}
