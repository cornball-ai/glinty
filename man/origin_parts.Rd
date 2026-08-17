% tinyrox says don't edit this manually, but it can't stop you!
\name{origin_parts}
\alias{origin_parts}
\title{Parse an Origin header value}
\usage{
origin_parts(origin)
}
\arguments{
\item{origin}{character Origin header value}
}
\value{
list(scheme, host, port) with port NA_integer_ when
  implied, or NULL when the value is not scheme://host[:port]
  (notably the opaque "null" origin)
}
\description{
Parse an Origin header value
}
\keyword{internal}
