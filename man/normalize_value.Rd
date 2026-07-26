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
multi-select values); collapse homogeneous ones to vectors.
}
\details{
Only *unnamed* lists collapse. A JSON object decodes to a named
list, and unlisting one would throw away the names and coerce
mixed types to a single mode -- exactly the wrong thing for an
object-valued input like Glinty.setInputValue("clip", \{data: ...,
size: ...\}), which arrives as a named list instead.

}
\keyword{internal}
