% tinyrox says don't edit this manually, but it can't stop you!
\name{ws_origin_allowed}
\alias{ws_origin_allowed}
\title{Decide whether an upgrade's Origin is acceptable}
\usage{
ws_origin_allowed(origin, host, origins = NULL)
}
\arguments{
\item{origin}{character Origin header value, or NULL when absent}

\item{host}{character Host header value, or NULL}

\item{origins}{character vector of additionally allowed origins,
containing "*" to disable the check, or NULL for same-host only}
}
\value{
logical
}
\description{
The policy behind the guard above. Same-host means the Origin's
host equals the request's Host and the ports agree -- explicit
ports numerically, an implied origin port (80/443 by scheme)
against a portless Host, which is a default-port deployment. The
comparison is Origin against Host, never against a hardcoded
localhost: an app reached over a tailnet has a tailnet Host, and
its own pages must keep connecting.
}
\keyword{internal}
