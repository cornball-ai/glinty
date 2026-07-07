% tinyrox says don't edit this manually, but it can't stop you!
\name{transport_rebind}
\alias{transport_rebind}
\title{Rebind a connection to a different session id}
\usage{
transport_rebind(from_sid, to_sid)
}
\arguments{
\item{from_sid}{character transport id assigned at upgrade}

\item{to_sid}{character session id being resumed}
}
\value{
logical success, invisibly
}
\description{
Resume support: a reconnecting client arrives on a fresh
connection under a fresh transport id; rebinding points the old
session id at the new connection so send_to_session() and event
routing keep working under the resumed identity.
}
\keyword{internal}
