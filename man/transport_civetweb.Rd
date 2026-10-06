% tinyrox says don't edit this manually, but it can't stop you!
\name{transport_civetweb}
\alias{transport_civetweb}
\title{The civetwebR transport}
\usage{
transport_civetweb()
}
\value{
a transport list
}
\description{
CivetWeb owns the sockets: it binds the given host, terminates TLS,
parses HTTP, performs the WebSocket handshake and frames. R sees
events from civetwebR::next_event() and answers them. What stays in
R is policy: the Origin check on an upgrade, the hello gate, and the
message-level rules the base transport applies (text only,
reassembly of fragments, the size cap).
}
\keyword{internal}
