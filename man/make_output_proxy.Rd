% tinyrox says don't edit this manually, but it can't stop you!
\name{make_output_proxy}
\alias{make_output_proxy}
\title{Create an output proxy for a session}
\usage{
make_output_proxy(session)
}
\arguments{
\item{session}{a glinty_session}
}
\value{
a glinty_output proxy
}
\description{
Assignments to output$id create observers that send `output`
messages to this session, typed by the renderer's kind. A bare
function is a text renderer; anything else comes from render_text()
and friends, which say what they produce.
}
\keyword{internal}
