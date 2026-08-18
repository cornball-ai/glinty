% tinyrox says don't edit this manually, but it can't stop you!
\name{feed_append}
\alias{feed_append}
\title{Append one item to a feed}
\usage{
feed_append(session, id, item)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character feed ID}

\item{item}{a component, the new entry}
}
\value{
invisible(NULL)
}
\description{
Sends the item alone; clients add it to the end and drop items past
`keep` from the top. While the reader is at the bottom the feed
stays pinned there.
}
\examples{
\dontrun{
feed_append(session, "room", text("hello", variant = "muted"))
}
}
