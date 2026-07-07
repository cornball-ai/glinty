% tinyrox says don't edit this manually, but it can't stop you!
\name{get_header}
\alias{get_header}
\title{Look up a request header}
\usage{
get_header(req, name)
}
\arguments{
\item{req}{a parsed request}

\item{name}{character lower-case header name}
}
\value{
character value, or NULL when absent
}
\description{
headers is a named character vector; [[ on a missing vector name
errors, so lookups go through here.
}
\keyword{internal}
