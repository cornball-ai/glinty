% tinyrox says don't edit this manually, but it can't stop you!
\name{update_msg}
\alias{update_msg}
\title{Create an update message}
\usage{
update_msg(id, property, value)
}
\arguments{
\item{id}{character element ID}

\item{property}{character DOM property to update}

\item{value}{new value}
}
\value{
character JSON string
}
\description{
The DOM patch used by all outputs: set one property on the element
with the given id.
}
\keyword{internal}
