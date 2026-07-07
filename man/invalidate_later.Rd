% tinyrox says don't edit this manually, but it can't stop you!
\name{invalidate_later}
\alias{invalidate_later}
\title{Invalidate the current reactive context after a delay}
\usage{
invalidate_later(millis, session = NULL)
}
\arguments{
\item{millis}{numeric delay in milliseconds}

\item{session}{a glinty_session; defaults to the current session}
}
\value{
invisible(NULL)
}
\description{
Schedules a one-shot invalidation of the calling observer or
reactive, causing it to re-run on the next flush after the delay.
Calling it again on re-run re-arms the timer, giving periodic
execution (Shiny semantics). Timers belonging to an ended session
do nothing when they fire.
}
\examples{
\dontrun{
output$clock <- render_text(function() {
    invalidate_later(1000)
    format(Sys.time())
})
}
}
