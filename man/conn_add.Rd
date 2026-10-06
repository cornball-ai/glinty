% tinyrox says don't edit this manually, but it can't stop you!
\name{conn_add}
\alias{conn_add}
\title{Register a newly accepted connection}
\usage{
conn_add(con, state = "ws_pending", key = NULL)
}
\arguments{
\item{con}{the transport's connection id}

\item{state}{character initial state ("ws_pending")}

\item{key}{character key to register under, or NULL to number it}
}
\value{
character connection key
}
\description{
Register a newly accepted connection
}
\keyword{internal}
