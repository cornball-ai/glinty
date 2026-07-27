% tinyrox says don't edit this manually, but it can't stop you!
\name{issue_ticket}
\alias{issue_ticket}
\title{Issue a transfer ticket for one resource}
\usage{
issue_ticket(session, id, purpose)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character resource id (an input id for uploads, a
download id for downloads)}

\item{purpose}{"upload" or "download"}
}
\value{
list(token, expires) where expires is the TTL in seconds
}
\description{
Issue a transfer ticket for one resource
}
\keyword{internal}
