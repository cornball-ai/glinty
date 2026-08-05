% tinyrox says don't edit this manually, but it can't stop you!
\name{parse_range}
\alias{parse_range}
\title{Parse a byte-range request header}
\usage{
parse_range(range, size)
}
\arguments{
\item{range}{character `Range` header value, or NULL}

\item{size}{numeric file size in bytes}
}
\value{
`NULL` to serve the whole file, `NA` when the range names
  bytes the file does not have (a 416), otherwise `list(from, to)`
  with inclusive zero-based offsets
}
\description{
Handles the single-range forms a media element actually sends:
`bytes=from-to`, `bytes=from-` (to the end) and `bytes=-suffix` (the
last n bytes). Anything else, multi-range included, returns `NULL`:
the whole file is always a valid answer to a range request, so an
unparsed header costs a fall back rather than an error.
}
\keyword{internal}
