% tinyrox says don't edit this manually, but it can't stop you!
\name{slider_input}
\alias{slider_input}
\title{Create a range slider}
\usage{
slider_input(
  id,
  label = "",
  min = 0,
  max = 1,
  value = NULL,
  step = NULL,
  emit = "live"
)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{numeric initial value; defaults to the midpoint, which
is where an HTML range input sits when given no value. Filling it
in here puts the position on the wire, so every frontend starts
the thumb in the same place instead of each applying its own
default.}

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
