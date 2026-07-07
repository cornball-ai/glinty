% tinyrox says don't edit this manually, but it can't stop you!
\name{parse_http_head}
\alias{parse_http_head}
\title{Parse an HTTP request head}
\usage{
parse_http_head(head_raw)
}
\arguments{
\item{head_raw}{raw bytes of the request line and headers (without
the terminating CRLFCRLF)}
}
\value{
list(method, path, query, headers) with lower-cased header
  names, or NULL on a malformed head
}
\description{
Parse an HTTP request head
}
\keyword{internal}
