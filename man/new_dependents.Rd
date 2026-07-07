% tinyrox says don't edit this manually, but it can't stop you!
\name{new_dependents}
\alias{new_dependents}
\title{Create a dependents registry}
\usage{
new_dependents()
}
\value{
An environment with register() and invalidate_all()
}
\description{
Each reactive source holds one of these. Tracks which contexts
depend on this source. On invalidation, all dependents are notified.
}
\keyword{internal}
