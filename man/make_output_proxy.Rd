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
Assignments to output$id create observers that send update messages
to this session. The DOM property defaults to textContent but can be
overridden by registering a property via output_property() or by
assigning a renderer created with render_html() and friends.
}
\keyword{internal}
