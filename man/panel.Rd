% tinyrox says don't edit this manually, but it can't stop you!
\name{panel}
\alias{panel}
\title{Group children in a container}
\usage{
panel(..., variant = "plain", title = NULL, id = NULL)
}
\arguments{
\item{...}{child components}

\item{variant}{character "plain", "card" or "sidebar"}

\item{title}{character heading shown above the contents}

\item{id}{character element ID}
}
\value{
A UI component
}
\description{
Group children in a container
}
\examples{
panel(txt("body"), variant = "card", title = "Results")
}
