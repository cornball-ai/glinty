% tinyrox says don't edit this manually, but it can't stop you!
\name{range_slider}
\alias{range_slider}
\title{Create a two-thumb range slider}
\usage{
range_slider(
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

\item{value}{numeric `c(lo, hi)` initial pair; NULL means the ends}

\item{step}{numeric step size; NULL for the implied precision}

\item{emit}{character "live" (default) or "settle"}

\item{min,max}{numeric bounds}
}
\value{
A UI component
}
\description{
One component, two thumbs: its value is the pair `c(lo, hi)` and
arrives server-side as a length-2 numeric vector. With no `value`
the thumbs start at the ends. `step` and `emit` behave exactly as
in [slider_input()]; a stepless range still drags at the implied
precision.
}
\examples{
range_slider("years", "Years:", min = 1990, max = 2030,
    value = c(2000, 2015), step = 1)
}
