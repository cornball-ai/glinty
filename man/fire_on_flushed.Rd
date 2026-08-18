% tinyrox says don't edit this manually, but it can't stop you!
\name{fire_on_flushed}
\alias{fire_on_flushed}
\title{Fire every session's pending on_flushed callbacks}
\usage{
fire_on_flushed()
}
\value{
integer count of callbacks fired, invisibly
}
\description{
Called by the event loop after the flush's messages have been
drained to the transports, and by the in-process driver after
flush_reactions(). Each callback runs once with its session
current (so reactive writes inside are attributed correctly) and
outside any reactive context. Returns how many fired, so the loop
can spin immediately instead of sleeping on state the client has
not seen.
}
\keyword{internal}
