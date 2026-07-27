% tinyrox says don't edit this manually, but it can't stop you!
\docType{data}
\name{PROTOCOL_VERSION}
\alias{PROTOCOL_VERSION}
\title{The protocol version this glinty speaks}
\format{
An object of class \code{integer} of length 1.
}
\usage{
PROTOCOL_VERSION
}
\description{
Carried in the fixture artifact and, from stage 2, in `hello` and
`welcome`, so a client can refuse a wire format it was not written
against rather than rendering half of it.
}
\keyword{internal}
