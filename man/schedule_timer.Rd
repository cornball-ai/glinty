% tinyrox says don't edit this manually, but it can't stop you!
\name{schedule_timer}
\alias{schedule_timer}
\title{Schedule a one-shot timer}
\usage{
schedule_timer(delay_s, fn, now = timer_now())
}
\arguments{
\item{delay_s}{numeric delay in seconds}

\item{fn}{zero-arg callback}

\item{now}{numeric current time (injectable for tests)}
}
\value{
integer timer id
}
\description{
Schedule a one-shot timer
}
\keyword{internal}
