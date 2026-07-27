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
principal$id (jwt_auth() puts sub there); a verifier that returns
principals without ids gives resume nothing to bind to, so an
authenticated resume is refused rather than cross-linked.
}
\details{
Without auth configured there is no identity to bind: the session
id alone remains the (documented, weak) resume credential.

}
\keyword{internal}
