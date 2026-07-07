% tinyrox says don't edit this manually, but it can't stop you!
\name{$<-.glinty_output}
\alias{$<-.glinty_output}
\title{Register an output renderer}
\usage{
\method{$<-}{glinty_output}(x, name, value)
}
\arguments{
\item{x}{a glinty_output proxy}

\item{name}{character output ID}

\item{value}{a function that computes the output, or a renderer
from render_text() and friends}
}
\value{
the proxy, invisibly
}
\description{
Register an output renderer
}
