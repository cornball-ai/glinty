% tinyrox says don't edit this manually, but it can't stop you!
\name{ws_decode_frame}
\alias{ws_decode_frame}
\title{Decode one frame from a buffer}
\usage{
ws_decode_frame(buf, max_payload = getOption("glinty.max_frame", 1048576L))
}
\arguments{
\item{buf}{raw vector}

\item{max_payload}{integer payload cap per frame}
}
\value{
NULL, frame-error, or list(fin, opcode, masked, payload, rest)
}
\description{
Returns NULL when the buffer does not yet hold a complete frame
(caller keeps the bytes and waits), a frame-error record on
protocol violations, or the decoded frame plus the unconsumed rest
of the buffer. Masking policy is the caller's: the decoded frame
reports masked so servers can require it.
}
\keyword{internal}
