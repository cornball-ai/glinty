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
has just been sent. Canonical means the serializer that produces
the wire form, so the hash is over exactly the bytes a client
parses.
}
\keyword{internal}
