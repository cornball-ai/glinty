% tinyrox says don't edit this manually, but it can't stop you!
\name{heading}
\alias{heading}
\title{Create a heading}
\usage{
heading(value, level = 2L, id = NULL)
}
\arguments{
\item{value}{character heading text}

\item{level}{integer 1 to 4}

\item{id}{character element ID}
}
\value{
A UI component
}
\description{
The level is a number rather than a tag name, so a client that has
no h1..h6 can map it onto its own type scale.
}
\examples{
heading("Results", level = 2L)
}
