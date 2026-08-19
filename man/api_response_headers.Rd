% tinyrox says don't edit this manually, but it can't stop you!
\name{api_response_headers}
\alias{api_response_headers}
\title{Validate the extra response headers}
\usage{
api_response_headers(h)
}
\arguments{
\item{h}{the router's headers element, or NULL}
}
\value{
named character vector, or NULL
}
\description{
Every element must be named and single-line: an unnamed element
emits a malformed head line, and a CR or LF smuggled through a
value taken from request data is response splitting. Both refuse
loudly into the sanitized 500 instead of going on the wire.
}
\keyword{internal}
