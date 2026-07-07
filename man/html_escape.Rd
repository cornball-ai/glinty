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
Escape text for safe HTML output
}
\examples{
html_escape("a <b> & \"c\"")
}
