% tinyrox says don't edit this manually, but it can't stop you!
\name{client_dim}
\alias{client_dim}
\title{Read a client-reported output dimension}
\usage{
client_dim(session, id, dim, fallback)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character output ID}

\item{dim}{character "width" or "height"}

\item{fallback}{numeric size before the client has reported}
}
\value{
numeric pixel dimension
}
\description{
The JS client reports each plot output's rendered box as reserved
inputs ..clientdata_output_<id>_width/_height (at init and on
window resize). Reading them here is a tracked reactive read, so
a resize re-renders the plot.
}
\keyword{internal}
