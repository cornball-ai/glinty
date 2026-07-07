% tinyrox says don't edit this manually, but it can't stop you!
\name{ws_close_frame}
\alias{ws_close_frame}
\title{Encode a close frame}
\usage{
ws_close_frame(code = 1000L, reason = "", mask = FALSE)
}
\arguments{
\item{code}{integer close code}

\item{reason}{character reason text}

\item{mask}{logical whether to mask (client role)}
}
\value{
raw frame bytes
}
\description{
Encode a close frame
}
\keyword{internal}
