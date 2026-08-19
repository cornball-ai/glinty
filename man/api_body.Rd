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
a plain nested list, or NULL
}
\description{
Absent, empty, non-UTF-8, and unparseable bodies all come back
NULL: the router sees "no body" and answers as it would for a
missing field, rather than glinty deciding what a malformed body
deserves.
}
\details{
Nothing is simplified: scalars stay scalars, arrays stay lists.
Simplification would turn an array of records into an NA-filled
data.frame, conflating a field a caller omitted with one it sent
as null -- the router owns that distinction, not the wire.

}
\keyword{internal}
