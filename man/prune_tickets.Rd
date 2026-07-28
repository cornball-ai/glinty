% tinyrox says don't edit this manually, but it can't stop you!
\name{prune_tickets}
\alias{prune_tickets}
\title{Drop expired tickets}
\usage{
prune_tickets()
}
\value{
invisible(NULL)
}
\description{
Called on every issue, so an app that mints tickets and never
redeems them still holds a bounded set.
}
\keyword{internal}
