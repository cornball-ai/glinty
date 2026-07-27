% tinyrox says don't edit this manually, but it can't stop you!
\name{const_time_eq}
\alias{const_time_eq}
\title{Compare two raw vectors in constant time}
\usage{
const_time_eq(a, b)
}
\arguments{
\item{a,b}{raw vectors}
}
\value{
logical
}
\description{
The comparison a signature check needs: every byte is examined
regardless of where the first mismatch sits, so timing does not
leak the prefix length.
}
\keyword{internal}
