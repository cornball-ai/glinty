% tinyrox says don't edit this manually, but it can't stop you!
\name{kill_all_jobs}
\alias{kill_all_jobs}
\title{Kill every job, whatever its scope}
\usage{
kill_all_jobs()
}
\value{
invisible(NULL)
}
\description{
For app shutdown. callr's supervisor would reap the children when
this process exits anyway; this makes it happen at a moment we
choose, and leaves the registry clean for the next run_app() in the
same session.
}
\keyword{internal}
