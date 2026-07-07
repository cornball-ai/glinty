% tinyrox says don't edit this manually, but it can't stop you!
\name{ws_ping_frame}
\alias{ws_ping_frame}
\title{Encode a ping frame (test client)}
\usage{
ws_ping_frame(payload = raw(0L), mask = FALSE)
}
\arguments{
\item{payload}{raw payload}

\item{mask}{logical whether to mask (client role)}
}
\value{
raw frame bytes
}
\description{
Encode a ping frame (test client)
}
\keyword{internal}
