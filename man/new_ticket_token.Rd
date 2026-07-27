% tinyrox says don't edit this manually, but it can't stop you!
\name{new_ticket_token}
\alias{new_ticket_token}
\title{Mint a ticket token}
\usage{
new_ticket_token()
}
\value{
character token
}
\description{
A ticket is a bearer credential, so the token comes from a real
CSPRNG, never from hashed process state a peer could reconstruct.
}
\keyword{internal}
