% tinyrox says don't edit this manually, but it can't stop you!
\name{find_header_end}
\alias{find_header_end}
\title{Find the end of an HTTP head in a buffer}
\usage{
find_header_end(buf)
}
\arguments{
\item{buf}{raw vector}
}
\value{
integer index of the first byte of the CRLFCRLF
  terminator, or -1 if not present yet
}
\description{
Find the end of an HTTP head in a buffer
}
\keyword{internal}
