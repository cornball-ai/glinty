% tinyrox says don't edit this manually, but it can't stop you!
\name{civet_request}
\alias{civet_request}
\title{A civetwebR event as a glinty request}
\usage{
civet_request(ev)
}
\arguments{
\item{ev}{a cw_request}
}
\value{
list(method, path, query, headers[, body])
}
\description{
The shape the router reads: method, path, query and headers with
lower-cased names, plus the raw body when there is one.
}
\keyword{internal}
