% tinyrox says don't edit this manually, but it can't stop you!
\name{send_input_update}
\alias{send_input_update}
\title{Queue an update_input message and sync server-side state}
\usage{
send_input_update(session, id, fields, sync_value = NULL)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{fields}{named list of update fields; NULLs are dropped}

\item{sync_value}{if non-NULL, the session's input value is set to
this (invalidating dependents) since the client applies the
update without echoing an input event back}
}
\value{
invisible(NULL)
}
\description{
Queue an update_input message and sync server-side state
}
\keyword{internal}
