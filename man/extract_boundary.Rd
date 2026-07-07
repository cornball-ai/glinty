% tinyrox says don't edit this manually, but it can't stop you!
\name{extract_boundary}
\alias{extract_boundary}
\title{Extract the boundary from a Content-Type header}
\usage{
extract_boundary(ct)
}
\arguments{
\item{ct}{character content-type header value}
}
\value{
character boundary, or NULL if this is not multipart
}
\description{
Extract the boundary from a Content-Type header
}
\keyword{internal}
