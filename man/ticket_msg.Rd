% tinyrox says don't edit this manually, but it can't stop you!
\name{ticket_msg}
\alias{ticket_msg}
\title{Create a ticket grant message}
\usage{
ticket_msg(id, purpose, token, expires)
}
\arguments{
\item{id}{character resource id the ticket covers}

\item{purpose}{"upload" or "download"}

\item{token}{character the ticket}

\item{expires}{numeric TTL in seconds (relative, so no clock sync
is asked of the client)}
}
\value{
character JSON string
}
\description{
Create a ticket grant message
}
\keyword{internal}
