% tinyrox says don't edit this manually, but it can't stop you!
\name{drop_progress}
\alias{drop_progress}
\title{Remove one handle from the progress stack}
\usage{
drop_progress(handle)
}
\arguments{
\item{handle}{the handle to drop}
}
\value{
the remaining stack
}
\description{
Removes by identity, so an inner bar closing out of order cannot
pop the wrong one.
}
\keyword{internal}
