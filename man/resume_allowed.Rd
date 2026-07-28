% tinyrox says don't edit this manually, but it can't stop you!
\name{resume_allowed}
\alias{resume_allowed}
\title{May this principal resume that session?}
\usage{
resume_allowed(old, principal, auth)
}
\arguments{
\item{old}{the detached glinty_session}

\item{principal}{the freshly verified principal}

\item{auth}{the configured verifier, or NULL}
}
\value{
logical
}
\description{
Authentication binds a session to an identity, and resume must
honour the binding: holding a valid token for user B plus user A's
session id must not replay A's outputs. The stable identity is
principal$id (jwt_auth() puts sub there).
}
\details{
A verifier may return anything non-NULL -- a bare string, a
vector, a list without an id -- and glinty keeps it as the
principal either way. Those simply have no identity to bind to, so
resume is disabled for them (a fresh session, not an error): a
principal glinty cannot compare is one it must not gamble on.

Without auth configured there is no identity at all: the session
id alone remains the (documented, weak) resume credential.

}
\keyword{internal}
