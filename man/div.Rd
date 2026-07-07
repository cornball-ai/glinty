% tinyrox says don't edit this manually, but it can't stop you!
\name{div}
\alias{div}
\title{Create a generic container}
\usage{
div(..., class = NULL, id = NULL)
}
\arguments{
\item{...}{child elements}

\item{class}{character CSS class(es)}

\item{id}{character element ID}
}
\value{
A UI element
}
\description{
Create a generic container
}
\examples{
div(h2("Section"), class = "sidebar")
}
