% tinyrox says don't edit this manually, but it can't stop you!
\name{raw_response_parts}
\alias{raw_response_parts}
\title{Split a raw HTTP response into its parts}
\usage{
raw_response_parts(resp)
}
\arguments{
\item{resp}{raw bytes of a full response}
}
\value{
list(status, headers, body)
}
\description{
The app layer builds complete responses with http_response_raw();
civetwebR wants status, headers and body separately and writes
Content-Length and Connection itself, so those two are dropped.
}
\keyword{internal}
