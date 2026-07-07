% tinyrox says don't edit this manually, but it can't stop you!
\name{header_has_token}
\alias{header_has_token}
\title{Test whether a header value contains a token}
\usage{
header_has_token(value, token)
}
\arguments{
\item{value}{character header value (or NULL/NA when absent)}

\item{token}{character lowercase token to look for}
}
\value{
logical
}
\description{
Header values like "keep-alive, Upgrade" are comma-separated token
lists compared case-insensitively.
}
\keyword{internal}
