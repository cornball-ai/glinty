% tinyrox says don't edit this manually, but it can't stop you!
\name{slider_input}
\alias{slider_input}
\title{Create a range slider}
\usage{
slider_input(id, label = "", min = 0, max = 1, value = NULL, step = NULL,
             emit = "live")
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{numeric initial value}

\item{step}{numeric step size; a frontend may derive its own
division count from it, which is why it is a number}

\item{emit}{character "live" or "settle"}

\item{min,max}{numeric bounds}
}
\value{
A UI component
}
\description{
Create a range slider
}
\examples{
slider_input("n", "Points:", min = 10, max = 500, value = 100, step = 10)
}
