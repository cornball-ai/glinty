% tinyrox says don't edit this manually, but it can't stop you!
\name{slider_input}
\alias{slider_input}
\title{Create a range slider input}
\usage{
slider_input(id, label = "", min = 0, max = 1, value = 0.5, step = 0.1)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{min}{numeric minimum value}

\item{max}{numeric maximum value}

\item{value}{numeric initial value}

\item{step}{numeric step size}
}
\value{
A UI element
}
\description{
Create a range slider input
}
\examples{
slider_input("n", "Points:", min = 10, max = 500, value = 100, step = 10)
}
