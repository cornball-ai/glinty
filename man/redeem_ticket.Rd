% tinyrox says don't edit this manually, but it can't stop you!
\name{redeem_ticket}
\alias{redeem_ticket}
\title{Redeem a ticket, once}
\usage{
redeem_ticket(token, purpose)
}
\arguments{
\item{token}{character ticket token from the URL}

\item{purpose}{"upload" or "download"; a ticket minted for one
never opens the other}
}
\value{
list(session, id), or NULL when the ticket is unknown,
  expired, for another purpose, or its session is gone
}
\description{
The ticket is consumed whether or not the transfer that follows
succeeds: a retry asks for a new one over the socket, which costs
nothing, and a replayed URL gets nothing.
}
\keyword{internal}
