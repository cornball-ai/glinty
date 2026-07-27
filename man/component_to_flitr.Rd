% tinyrox says don't edit this manually, but it can't stop you!
\name{component_to_flitr}
\alias{component_to_flitr}
\title{Lower a component tree to flitR ops}
\usage{
component_to_flitr(x, session, unsupported)
}
\arguments{
\item{x}{a glinty_component}

\item{session}{the native session}

\item{unsupported}{collector env with a `$names` character vector}
}
\value{
a flitR item, or NULL to contribute nothing
}
\description{
Lower a component tree to flitR ops
}
\keyword{internal}
