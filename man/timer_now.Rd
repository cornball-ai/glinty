% tinyrox says don't edit this manually, but it can't stop you!
\name{timer_now}
\alias{timer_now}
\title{Current scheduler time}
\usage{
timer_now()
}
\value{
numeric epoch seconds
}
\description{
Wall-clock seconds. Every scheduler function takes an injectable
now so tests can drive the clock by hand.
}
\keyword{internal}
