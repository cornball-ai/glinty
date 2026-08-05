% tinyrox says don't edit this manually, but it can't stop you!
\name{ws_encode_frame}
\alias{ws_encode_frame}
\title{Encode one frame}
\usage{
ws_encode_frame(
  opcode,
  payload = raw(0L),
  mask = FALSE,
  fin = TRUE,
  key = NULL
)
}
\arguments{
\item{opcode}{integer frame opcode}

\item{payload}{raw payload}

\item{mask}{logical whether to mask (client role)}

\item{fin}{logical final-fragment flag}

\item{key}{raw(4) mask key; random when NULL}
}
\value{
raw frame bytes
}
\description{
Server frames are never masked; mask = TRUE exists for the test
client, which must mask like a browser. A fixed key makes masked
encoding deterministic for tests.
}
\keyword{internal}
