% tinyrox says don't edit this manually, but it can't stop you!
\name{feed_state}
\alias{feed_state}
\title{Per-session feed state, created on first touch}
\usage{
feed_state(session, id)
}
\description{
`keep` comes from the feed's declaration in the static UI tree when
the id is found there, and from the schema default otherwise (a
feed born inside render_ui() is not in that tree). Held server-side
so the log and the clients trim to the same bound -- every feed
message carries it, so no client reads a second source at runtime.
}
\keyword{internal}
