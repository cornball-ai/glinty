% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_http_bytes}
\alias{handle_http_bytes}
\title{Advance an http_pending connection}
\usage{
handle_http_bytes(key, handlers)
}
\arguments{
\item{key}{character connection key}

\item{handlers}{the handler list}
}
\value{
invisible(NULL)
}
\description{
Waits for a complete head, then routes: WebSocket upgrades promote
the connection and open a session; anything else gets a plain HTTP
response and Connection: close. GET only in v0.1 -- the WebSocket
carries the app after page load.
}
\keyword{internal}
