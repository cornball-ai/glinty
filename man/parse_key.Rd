% tinyrox says don't edit this manually, but it can't stop you!
\name{parse_key}
\alias{parse_key}
\title{Parse a key spec into its wire fields}
\usage{
parse_key(spec)
}
\arguments{
\item{spec}{character like "ctrl+shift+k", "space", "f5"}
}
\value{
list(key, ctrl, shift, alt)
}
\description{
Parse a key spec into its wire fields
}
\keyword{internal}
