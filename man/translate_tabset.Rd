% tinyrox says don't edit this manually, but it can't stop you!
\name{translate_tabset}
\alias{translate_tabset}
\title{Translate a tabset}
\usage{
translate_tabset(tg, session, values, unsupported)
}
\arguments{
\item{tg}{the g-tabset glinty_tag}

\item{session}{the native session}

\item{values}{output value env}

\item{unsupported}{collector env}
}
\value{
a flitR item, or NULL
}
\description{
The nav strip comes from flitR::tabs(); below it only the selected
panel is emitted. That is the immediate-mode reading of a tab: an
unselected panel is not hidden, it is simply not drawn this frame,
which is also why the browser's DOM-preserving behaviour (inputs
keeping their values while hidden) does not carry over.
}
\details{
Switching needs somewhere to hold the selection, and the only
durable place is the tabset's own input. A tabset without an id has
nowhere to put it, so rather than draw a nav that does nothing when
clicked, say so.

}
\keyword{internal}
