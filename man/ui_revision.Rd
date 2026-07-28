% tinyrox says don't edit this manually, but it can't stop you!
\name{ui_revision}
\alias{ui_revision}
\title{The SHA-256 of a component tree's wire form}
\usage{
ui_revision(ui)
}
\arguments{
\item{ui}{a page component}
}
\value{
character lowercase hex sha256
}
\description{
Sent in `welcome` and embedded in any pre-rendered document, so a
client can tell whether markup it was handed describes the tree it
has just been sent.
}
\details{
The value is opaque to clients: they compare it for string
equality and never compute, parse, or shape-check it. The hash
algorithm and the canonical serialization (the same one that
produces the wire form) bind this server alone, which is what
keeps R's JSON habits out of every other language.

}
\keyword{internal}
