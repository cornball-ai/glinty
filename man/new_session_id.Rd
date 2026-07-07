% tinyrox says don't edit this manually, but it can't stop you!
\name{new_session_id}
\alias{new_session_id}
\title{Generate a session id}
\usage{
new_session_id()
}
\value{
character session id
}
\description{
32 hex characters. Restores .Random.seed so server traffic does
not perturb user RNG streams. The id is a routing label, never an
authenticator: a fresh WebSocket always gets a fresh session.
}
\keyword{internal}
