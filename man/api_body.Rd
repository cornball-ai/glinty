% tinyrox says don't edit this manually, but it can't stop you!
\name{api_body}
\alias{api_body}
\title{Decode an api request body as JSON}
\usage{
api_body(req)
}
\arguments{
\item{req}{parsed request}
}
\value{
a named list, or NULL
}
\description{
Absent, empty, non-UTF-8, and unparseable bodies all come back
NULL: the router sees "no body" and answers as it would for a
missing field, rather than glinty deciding what a malformed body
deserves.
}
\keyword{internal}
