% tinyrox says don't edit this manually, but it can't stop you!
\name{loop_tick}
\alias{loop_tick}
\title{One iteration of the event loop}
\usage{
loop_tick(srv, handlers, max_tick)
}
\arguments{
\item{srv}{the server socket}

\item{handlers}{the handler list}

\item{max_tick}{numeric maximum select timeout in seconds}
}
\value{
invisible(NULL)
}
\description{
One iteration of the event loop
}
\keyword{internal}
