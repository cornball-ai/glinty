% tinyrox says don't edit this manually, but it can't stop you!
\name{next_timer_deadline}
\alias{next_timer_deadline}
\title{Seconds until the next timer fires}
\usage{
next_timer_deadline(now = timer_now())
}
\arguments{
\item{now}{numeric current time (injectable for tests)}
}
\value{
numeric seconds (>= 0), or NULL if no timers are scheduled
}
\description{
Used by the event loop as its socketSelect timeout.
}
\keyword{internal}
