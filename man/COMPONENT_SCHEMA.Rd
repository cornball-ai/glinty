% tinyrox says don't edit this manually, but it can't stop you!
\docType{data}
\name{COMPONENT_SCHEMA}
\alias{COMPONENT_SCHEMA}
\title{Component field schemas}
\format{
An object of class \code{list} of length 43.
}
\usage{
COMPONENT_SCHEMA
}
\description{
Every component's fields, with types, bounds and defaults.
Construction validates against this, so a malformed component fails
where it was written rather than in a client -- or worse, in one
client and not another.
}
\keyword{internal}
