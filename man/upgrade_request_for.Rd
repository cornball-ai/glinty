% tinyrox says don't edit this manually, but it can't stop you!
\name{upgrade_request_for}
\alias{upgrade_request_for}
\title{The HTTP request that upgraded a session's connection}
\usage{
upgrade_request_for(sid)
}
\arguments{
\item{sid}{character session id}
}
\value{
the parsed upgrade request, or NULL when the session has
  no live connection or the connection kept none
}
\description{
The parsed head only (method, path, query, headers with lower-cased
names) -- small and bounded by MAX_HTTP_HEAD, never the raw buffer.
It lives as long as the connection, which is exactly the lifetime
the hello gate needs it for: a verifier that reads cookie-carried
credentials (see authenticate_hello()) runs on the first frame of
the same connection.
}
\keyword{internal}
