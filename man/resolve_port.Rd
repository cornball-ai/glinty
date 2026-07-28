% tinyrox says don't edit this manually, but it can't stop you!
\name{resolve_port}
\alias{resolve_port}
\title{Resolve the port to serve on}
\usage{
resolve_port(port)
}
\arguments{
\item{port}{integer or NULL}
}
\value{
integer port
}
\description{
An explicit port wins. NULL reads GLINTY_PORT then PORT from the
environment -- a scheduler that allocates ports sets one of those
-- and falls back to 8080.
}
\keyword{internal}
