% tinyrox says don't edit this manually, but it can't stop you!
\name{page}
\alias{page}
\title{Create an HTML page}
\usage{
page(..., title = "glinty app")
}
\arguments{
\item{...}{child elements}

\item{title}{character page title}
}
\value{
A UI tree (glinty_tag with a title field)
}
\description{
The top-level UI container. The title becomes the browser tab
title when the page is served.
}
\examples{
page(h1("Hello"), title = "My app")
}
