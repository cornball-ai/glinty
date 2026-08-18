% tinyrox says don't edit this manually, but it can't stop you!
\name{feed_patch}
\alias{feed_patch}
\title{Rewrite the newest item of a feed}
\usage{
feed_patch(session, id, item)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character feed ID}

\item{item}{a component, replacing the newest entry}
}
\value{
invisible(NULL)
}
\description{
The streaming case: the message being generated is appended once,
then patched as tokens arrive. Patching an empty feed is an error
-- there is nothing the patch could mean.
}
\examples{
\dontrun{
feed_append(session, "room", text(""))
feed_patch(session, "room", text(draft_so_far))
}
}
