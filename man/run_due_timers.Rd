% tinyrox says don't edit this manually, but it can't stop you!
\name{run_due_timers}
\alias{run_due_timers}
\title{Run all timers that are due}
\usage{
run_due_timers(now = timer_now())
}
\arguments{
\item{now}{numeric current time (injectable for tests)}
}
\value{
integer count of fired timers, invisibly
}
\description{
Pops and calls every timer with at <= now, each wrapped in
tryCatch so one failing callback cannot take down the loop.
}
\keyword{internal}
