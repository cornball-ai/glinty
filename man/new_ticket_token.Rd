% tinyrox says don't edit this manually, but it can't stop you!
\name{new_ticket_token}
\alias{new_ticket_token}
\title{Mint an unguessable ticket token}
\usage{
new_ticket_token()
}
\value{
character token
}
\description{
Same recipe as session ids: process, clock, counter and a
tempfile name through sha1. Unguessable at the "seconds-lived,
single-use, LAN tool" scope this serves.
}
\keyword{internal}
