% tinyrox says don't edit this manually, but it can't stop you!
\name{respond_and_close}
\alias{respond_and_close}
\title{Route a complete request and close the connection}
\usage{
respond_and_close(key, req, handlers)
}
\arguments{
\item{key}{character connection key}

\item{req}{parsed request (with body when present)}

\item{handlers}{the handler list}
}
\value{
invisible(NULL)
}
\description{
Route a complete request and close the connection
}
\keyword{internal}
