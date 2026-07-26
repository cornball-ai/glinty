% tinyrox says don't edit this manually, but it can't stop you!
\name{raw_head_html}
\alias{raw_head_html}
\title{Serialize the escape-hatch head content}
\usage{
raw_head_html(extra)
}
\arguments{
\item{extra}{a glinty_tag, character, or NULL}
}
\value{
character HTML
}
\description{
A glinty_tag is serialized; character is trusted as-is, since the
whole point of the escape hatch is emitting markup glinty has no
constructor for.
}
\keyword{internal}
