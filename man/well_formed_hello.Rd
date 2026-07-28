% tinyrox says don't edit this manually, but it can't stop you!
\name{well_formed_hello}
\alias{well_formed_hello}
\title{Is this first frame a hello worth authenticating?}
\usage{
well_formed_hello(msg)
}
\arguments{
\item{msg}{decoded first frame, or NULL when it failed to parse}
}
\value{
logical
}
\description{
The first frame must be a well-formed hello before anything else
happens -- before the verifier runs, before a session exists.
Anything else is refused outright, which also gives a protocol 2
client's init frame an answer instead of a silently dead app.
}
\keyword{internal}
