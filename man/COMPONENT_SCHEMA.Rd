% tinyrox says don't edit this manually, but it can't stop you!
\docType{data}
\name{COMPONENT_SCHEMA}
\alias{COMPONENT_SCHEMA}
\title{Component field schemas}
\format{
An object of class \code{list} of length 11.
}
\usage{
COMPONENT_SCHEMA
}
\description{
Declares every component's required and optional fields, plus
defaults for the optional ones. Construction validates against this,
so a malformed component fails where it was written rather than in a
client.
}
\details{
`children` is called out separately because it nests components
rather than holding scalars, and lowerings recurse on it.

}
\keyword{internal}
