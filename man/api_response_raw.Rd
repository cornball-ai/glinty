% tinyrox says don't edit this manually, but it can't stop you!
\name{api_response_raw}
\alias{api_response_raw}
\title{Encode an api result as a raw HTTP response}
\usage{
api_response_raw(res)
}
\arguments{
\item{res}{list(status =, body = | file =, content_type =,
headers =)}
}
\value{
raw HTTP response
}
\description{
`file` answers binary (content_type given, or guessed from the
extension); a NULL `body` answers empty (204s, redirects);
anything else is encoded as JSON with auto-unboxing, the encoding
a scalar-in-a-list R payload means. A named `headers` element
passes through for Set-Cookie and Location.
}
\keyword{internal}
