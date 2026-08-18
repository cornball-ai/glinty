% tinyrox says don't edit this manually, but it can't stop you!
\name{feed_send}
\alias{feed_send}
\title{Queue a live feed message and record the replay snapshot}
\usage{
feed_send(session, id, st, msg)
}
\description{
Mirrors send_output()'s contract: the snapshot (a reset carrying
the current window) is always recorded under a key no app id can
collide with -- ".." ids are refused on the input path -- and the
live delta is queued only while attached, because a resume replays
the snapshot instead.
}
\keyword{internal}
