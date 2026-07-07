% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_http_body}
\alias{handle_http_body}
\title{Advance an http_body connection}
\usage{
handle_http_body(key, handlers)
}
\arguments{
\item{key}{character connection key}

\item{handlers}{the handler list}
}
\value{
invisible(NULL)
}
\description{
Waits until the buffered bytes cover the declared Content-Length,
then routes the request with its raw body (never coerced to
character -- uploads are binary).
}
\keyword{internal}
