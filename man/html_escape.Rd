% tinyrox says don't edit this manually, but it can't stop you!
\name{html_escape}
\alias{html_escape}
\title{Escape text for safe HTML output}
\usage{
html_escape(x)
}
\arguments{
\item{x}{character string}
}
\value{
character with &, <, >, " escaped
}
\description{
Only needed when building a string for \code{\link{tag}()}. Text
carried by a component is escaped by the frontend that renders it,
so escaping it here would double-escape and show the entities.
}
\examples{
html_escape("a <b> & \"c\"")
}
\seealso{
\code{\link{tag}}
}
