% tinyrox says don't edit this manually, but it can't stop you!
\name{principal_id}
\alias{principal_id}
\title{The comparable identity in a principal, if it has one}
\usage{
principal_id(principal)
}
\arguments{
\item{principal}{whatever the verifier returned}
}
\value{
a length-1 character id, or NULL when there is none to
  compare (including for non-list principals, which cannot carry
  one)
}
\description{
The comparable identity in a principal, if it has one
}
\keyword{internal}
