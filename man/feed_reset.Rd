% tinyrox says don't edit this manually, but it can't stop you!
\name{feed_reset}
\alias{feed_reset}
\title{Replace a feed's window}
\usage{
feed_reset(session, id, items = list())
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character feed ID}

\item{items}{list of components}
}
\value{
invisible(NULL)
}
\description{
One message carrying the whole (trimmed) list: loading a room's
history at boot, or clearing with `items = list()`. The reader is
pinned back to the bottom.
}
\examples{
\dontrun{
feed_reset(session, "room", lapply(history, message_row))
}
}
