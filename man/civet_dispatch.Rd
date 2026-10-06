% tinyrox says don't edit this manually, but it can't stop you!
\name{civet_dispatch}
\alias{civet_dispatch}
\title{Dispatch one civetwebR event}
\usage{
civet_dispatch(ev, handlers, srv)
}
\arguments{
\item{ev}{a cw_request from civetwebR::next_event()}

\item{handlers}{the handler list}

\item{srv}{the civetwebR server handle}
}
\value{
invisible(NULL)
}
\description{
Dispatch one civetwebR event
}
\keyword{internal}
