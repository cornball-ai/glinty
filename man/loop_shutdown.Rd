% tinyrox says don't edit this manually, but it can't stop you!
\name{loop_shutdown}
\alias{loop_shutdown}
\title{Shut the server down}
\usage{
loop_shutdown(handlers)
}
\arguments{
\item{handlers}{the handler list}
}
\value{
invisible(NULL)
}
\description{
Closes every connection (1001 going away, with session teardown)
and the listening socket.
}
\keyword{internal}
