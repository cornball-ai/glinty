% tinyrox says don't edit this manually, but it can't stop you!
\name{number_input}
\alias{number_input}
\title{Create a numeric input}
\usage{
number_input(id, label = "", value = NULL, min = NULL, max = NULL, step = NULL)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{numeric initial value}

\item{min}{numeric minimum (optional)}

\item{max}{numeric maximum (optional)}

\item{step}{numeric step size (optional)}
}
\value{
A UI element
}
\description{
Create a numeric input
}
\examples{
number_input("k", "Clusters:", value = 3, min = 1, max = 10)
}
