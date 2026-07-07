% tinyrox says don't edit this manually, but it can't stop you!
\name{http_response_raw}
\alias{http_response_raw}
\title{Build a complete HTTP response}
\usage{
http_response_raw(status, content_type, body, extra_headers = NULL)
}
\arguments{
\item{status}{integer HTTP status code}

\item{content_type}{character MIME type}

\item{body}{character or raw response body}

\item{extra_headers}{named character vector of additional headers}
}
\value{
raw bytes of the full response
}
\description{
Always Connection: close -- the page loads once and the WebSocket
carries the app afterwards, so keep-alive buys nothing.
}
\keyword{internal}
