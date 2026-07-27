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
list(token, expires) where expires is the TTL in seconds,
  or NULL at the session's live-ticket cap
}
\description{
Bounded per session even within the TTL: pruning expired tickets
does not stop a client minting thousands inside one TTL window,
and no real page runs dozens of simultaneous transfers. At the cap
the request is dropped; a legitimate client retries after its
in-flight transfers finish.
}
\keyword{internal}
