% tinyrox says don't edit this manually, but it can't stop you!
\name{refuse_conn}
\alias{refuse_conn}
\title{Refuse a connection before any session exists}
\usage{
refuse_conn(sid, message)
}
\arguments{
\item{sid}{character transport session id}

\item{message}{character reason shown to the client}
}
\value{
invisible(NULL)
}
\description{
Sends one error frame so the refusal is visible client-side, then
marks the transport dead; the close happens at the top of the next
loop tick, after the frame has been written.
}
\keyword{internal}
