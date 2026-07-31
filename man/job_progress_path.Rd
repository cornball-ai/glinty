% tinyrox says don't edit this manually, but it can't stop you!
\name{job_progress_path}
\alias{job_progress_path}
\title{Where this process reports job progress, if it is a job}
\usage{
job_progress_path()
}
\value{
character path, or NULL in a process that is not a job
}
\description{
Set on the child by job_spawn(), read by set_progress() and
inc_progress(). An environment variable rather than an argument
because the job's function belongs to the app: adding a parameter
to it would make every job that wants progress take one, and every
job that does not carry a spare.
}
\keyword{internal}
