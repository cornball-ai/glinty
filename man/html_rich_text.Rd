% tinyrox says don't edit this manually, but it can't stop you!
\name{html_rich_text}
\alias{html_rich_text}
\title{Lower styled runs to spans}
\usage{
html_rich_text(x)
}
\description{
One span per run, marks as classes -- never nested tags, so the
element structure is exactly the run structure and a client
reading it back sees the wire form. A run with href becomes an
anchor; the schema already refused any scheme worth refusing.
white-space: pre-wrap on the paragraph (see .g-richtext) keeps the
newlines and indent the runs carry.
}
\keyword{internal}
