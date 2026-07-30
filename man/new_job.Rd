% tinyrox says don't edit this manually, but it can't stop you!
\name{new_job}
\alias{new_job}
\title{Build a job handle}
\usage{
new_job(fn, args, lane, scope, session)
}
\arguments{
\item{fn}{function to run}

\item{args}{list of arguments}

\item{lane}{character lane name}

\item{scope}{"session" or "app"}

\item{session}{the owning glinty_session, or NULL for app scope}
}
\value{
a glinty_job
}
\description{
Status, result and error live in one reactive value rather than
three, because they settle together: a reader taking them from
separate values could see this run's "done" beside the last run's
result in the window between two flushes.
}
\keyword{internal}
