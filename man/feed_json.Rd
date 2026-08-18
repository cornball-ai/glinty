% tinyrox says don't edit this manually, but it can't stop you!
\name{feed_json}
\alias{feed_json}
\title{Serialize one feed message, the way every outgoing message is}
\usage{
feed_json(msg)
}
\description{
Messages enter the queue as JSON text (welcome_msg() sets the
convention); the drain writes them as-is.
}
\keyword{internal}
