% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_hello}
\alias{handle_hello}
\title{Record what a client declared in hello}
\usage{
handle_hello(session, msg)
}
\arguments{
\item{session}{a glinty_session}

\item{msg}{decoded hello message}
}
\value{
invisible(NULL)
}
\description{
A declaration, not a negotiation: the server sends the whole tree
regardless and the client draws placeholders for what it cannot
render. Recording it lets render_ui() branch per session and makes
the gap diagnosable. The welcome is sent by the session-start
path, never from here, so a redeclaring reconnect cannot trigger a
second bootstrap.
}
\keyword{internal}
