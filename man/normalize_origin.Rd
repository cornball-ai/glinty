% tinyrox says don't edit this manually, but it can't stop you!
\name{normalize_origin}
\alias{normalize_origin}
\title{Normalize an origin for allowlist comparison}
\usage{
normalize_origin(origin)
}
\arguments{
\item{origin}{character origin string}
}
\value{
character normalized origin, or NULL when unparseable
}
\description{
Lowercased, default port stripped, so "https://a.example:443" and
"https://a.example" are the same entry whichever way the browser
or the app spelled it.
}
\keyword{internal}
