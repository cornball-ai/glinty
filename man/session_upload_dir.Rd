% tinyrox says don't edit this manually, but it can't stop you!
\name{session_upload_dir}
\alias{session_upload_dir}
\title{Lazily create a session's upload directory}
\usage{
session_upload_dir(session)
}
\arguments{
\item{session}{a glinty_session}
}
\value{
character directory path
}
\description{
Registered for recursive removal when the session ends.
}
\keyword{internal}
