% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_ws_bytes}
\alias{handle_ws_bytes}
\title{Advance a ws_open connection}
\usage{
handle_ws_bytes(key, handlers)
}
\arguments{
\item{key}{character connection key}

\item{handlers}{the handler list}
}
\value{
invisible(NULL)
}
\description{
Decodes and dispatches EVERY complete frame in the buffer (a
single readable event can deliver several), leaving partial bytes
for the next wake. Client frames must be masked. Fragmented text
is reassembled; control frames may interleave.
}
\keyword{internal}
