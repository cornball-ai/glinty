% tinyrox says don't edit this manually, but it can't stop you!
\name{native_apply}
\alias{native_apply}
\title{Apply a protocol message to the native value store}
\usage{
native_apply(msg_json, values, native)
}
\arguments{
\item{msg_json}{character one protocol message}

\item{values}{output value env}

\item{native}{native loop state env}
}
\value{
invisible(NULL)
}
\description{
The native backend is a client of the same wire protocol the
browser speaks: update messages set output values, errors show as
text, update_input redraws (the server side already synced the
input value). Any change marks the scene dirty.
}
\keyword{internal}
