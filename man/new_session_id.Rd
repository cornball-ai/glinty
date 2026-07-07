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
32 hex characters from digest over pid, wall clock, a monotonic
counter, and a tempfile name. Deliberately NOT the R RNG: an
earlier save/restore-.Random.seed approach replayed the same draw
on every call after the first, so consecutive ids collided and
sessions swallowed each other's connections. The counter
guarantees in-process uniqueness. Within the resume grace window
the id acts as a weak credential; see ?run_app for scope.
}
\keyword{internal}
