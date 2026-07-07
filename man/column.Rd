% tinyrox says don't edit this manually, but it can't stop you!
\name{column}
\alias{column}
\title{Arrange children in a vertical column}
\usage{
column(..., gap = NULL)
}
\arguments{
\item{...}{child elements}

\item{gap}{numeric gap between children in pixels (frontend
default when NULL)}
}
\value{
A UI element
}
\description{
The explicit counterpart of row(); maps to a flexbox column in the
browser and flitR's column layout natively.
}
\examples{
column(h3("Stack"), text_output("a"), text_output("b"))
}
