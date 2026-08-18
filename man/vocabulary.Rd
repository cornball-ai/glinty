% tinyrox says don't edit this manually, but it can't stop you!
\name{vocabulary}
\alias{vocabulary}
\title{The vocabulary as data: component names and variant lists}
\usage{
vocabulary()
}
\value{
list(components, variants)
}
\description{
What the R schema declares, in the schema's own order, for clients
to check their declaration tables against. Those tables cannot be
generated -- a support list states what a client implements, and a
variant list gates that client's own style maps -- so the honest
relation is verified restatement: each client asserts its tables
against this block in its own suite, and a vocabulary change fails
the client that has not answered for it instead of falling back
silently.
}
\details{
Order matters for variants: the first listed value is the fallback
an unknown variant takes, and a test asserts it is also the schema
default.

}
\keyword{internal}
