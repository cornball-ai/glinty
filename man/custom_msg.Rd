% tinyrox says don't edit this manually, but it can't stop you!
\name{custom_msg}
\alias{custom_msg}
\title{Create a custom message}
\usage{
custom_msg(handler, value)
}
\arguments{
\item{handler}{character handler name}

\item{value}{the payload, serialized as JSON}
}
\value{
character JSON string
}
\description{
The server-to-app-JavaScript channel: the client looks up handler
among those registered with Glinty.addCustomMessageHandler() and
calls it with value.
}
\keyword{internal}
