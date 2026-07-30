% tinyrox says don't edit this manually, but it can't stop you!
\name{kill_session_jobs}
\alias{kill_session_jobs}
\title{Kill every job a session started}
\usage{
kill_session_jobs(session_id)
}
\arguments{
\item{session_id}{character session id}
}
\value{
invisible(NULL)
}
\description{
Called from session_end() and nowhere else, which is what gives
jobs the lifetime the docs claim: a dropped connection only detaches
a session, so a job outlives a reconnect and dies when the resume
grace expires with nobody having come back.
}
\keyword{internal}
