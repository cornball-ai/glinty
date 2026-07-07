% tinyrox says don't edit this manually, but it can't stop you!
\name{ws_deliver}
\alias{ws_deliver}
\title{Deliver a complete text payload to the app layer}
\usage{
ws_deliver(key, payload, handlers)
}
\arguments{
\item{key}{character connection key}

\item{payload}{raw UTF-8 bytes}

\item{handlers}{the handler list}
}
\value{
logical FALSE if the connection was failed
}
\description{
Deliver a complete text payload to the app layer
}
\keyword{internal}
