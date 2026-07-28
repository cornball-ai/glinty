% tinyrox says don't edit this manually, but it can't stop you!
\name{number_input}
\alias{number_input}
\title{Create a numeric input}
\usage{
number_input(id, label = "", value = NULL, min = NULL, max = NULL, step = NULL,
             emit = "live")
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{numeric initial value}

\item{step}{numeric step size}

\item{emit}{character "live" or "settle"}

\item{min,max}{numeric bounds}
}
\value{
A UI component
}
\description{
Create a numeric input
}
\examples{
number_input("k", "Clusters:", value = 3, min = 1, max = 10)
}
