% tinyrox says don't edit this manually, but it can't stop you!
\name{normalize_value}
\alias{normalize_value}
\title{Normalize a JSON-decoded input value}
\usage{
normalize_value(value)
}
\arguments{
\item{value}{a decoded JSON value}
}
\value{
an R value suitable for a reactive_val
}
\description{
fromJSON(simplifyVector = FALSE) leaves arrays as lists (e.g.
multi-select values); collapse homogeneous lists to vectors.
}
\keyword{internal}
