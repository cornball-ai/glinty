% tinyrox says don't edit this manually, but it can't stop you!
\name{print.glinty_component}
\alias{print.glinty_component}
\title{Print a component as its wire form}
\usage{
\method{print}{glinty_component}(x, ...)
}
\arguments{
\item{x}{a glinty_component}

\item{...}{ignored}
}
\value{
x, invisibly
}
\description{
Shows exactly what a client receives, which is the useful view when
the question is why a frontend rendered something unexpected.
}
\examples{
\dontrun{
print(glinty:::component("text", value = "hello"))
}
}
