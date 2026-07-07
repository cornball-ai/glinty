% tinyrox says don't edit this manually, but it can't stop you!
\name{frame_error}
\alias{frame_error}
\title{Signal a protocol error from the decoder}
\usage{
frame_error(code, reason)
}
\arguments{
\item{code}{integer WebSocket close code}

\item{reason}{character human-readable reason}
}
\value{
a frame-error record
}
\description{
Signal a protocol error from the decoder
}
\keyword{internal}
