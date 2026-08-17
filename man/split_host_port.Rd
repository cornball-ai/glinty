% tinyrox says don't edit this manually, but it can't stop you!
\name{split_host_port}
\alias{split_host_port}
\title{Split a host[:port] authority}
\usage{
split_host_port(value)
}
\arguments{
\item{value}{character Host header value or origin authority}
}
\value{
list(host, port) with port NA_integer_ when absent, or
  NULL when the value is not a well-formed authority
}
\description{
Handles bracketed IPv6 ("[::1]:8080"). Lowercases, because host
names compare case-insensitively.
}
\keyword{internal}
