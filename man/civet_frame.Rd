% tinyrox says don't edit this manually, but it can't stop you!
\name{civet_frame}
\alias{civet_frame}
\title{Apply the message rules to one civetwebR data frame}
\usage{
civet_frame(key, entry, ev, handlers)
}
\arguments{
\item{key}{character connection key}

\item{entry}{registry entry}

\item{ev}{the ws_message event}

\item{handlers}{the handler list}
}
\value{
invisible(NULL)
}
\description{
Binary frames fail the connection with 1003, a continuation without
an open message or a new message inside one with 1002, an
over-sized message with 1009; a complete text message is delivered
through ws_deliver(), which checks the UTF-8.
}
\keyword{internal}
