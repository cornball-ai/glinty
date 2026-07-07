% tinyrox says don't edit this manually, but it can't stop you!
\name{as_renderer}
\alias{as_renderer}
\title{Coerce an output value to a renderer}
\usage{
as_renderer(value, default_prop = "textContent")
}
\arguments{
\item{value}{a function or glinty_renderer}

\item{default_prop}{character DOM property for bare functions}
}
\value{
a glinty_renderer list
}
\description{
A bare function becomes a textContent renderer whose value is
coerced to character. Renderers pass through unchanged.
}
\keyword{internal}
