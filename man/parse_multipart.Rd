% tinyrox says don't edit this manually, but it can't stop you!
\name{parse_multipart}
\alias{parse_multipart}
\title{Parse a multipart/form-data body}
\usage{
parse_multipart(body, boundary)
}
\arguments{
\item{body}{raw request body}

\item{boundary}{character boundary string (without leading --)}
}
\value{
named list; each element is a LIST of parts (one per
  occurrence of the field name), each part being
  list(value = raw, filename = character or NA)
}
\description{
Parse a multipart/form-data body
}
\keyword{internal}
