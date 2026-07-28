% tinyrox says don't edit this manually, but it can't stop you!
\name{ticket_refusal_msg}
\alias{ticket_refusal_msg}
\title{Create a ticket refusal message}
\usage{
ticket_refusal_msg(id, purpose, message)
}
\arguments{
\item{id}{character resource id the request named}

\item{purpose}{"upload" or "download"}

\item{message}{character why}
}
\value{
character JSON string
}
\description{
The answer to a request the server will not grant: a `ticket` frame
carrying `error` where a grant carries `token`.
}
\details{
A refusal used to travel as an `error` frame scoped to the resource
id, which made `error` mean two unrelated things -- "this output
failed to render" and "your transfer was refused" -- and left the
two clients disagreeing about which. Answering the request on the
channel it was made on is both simpler and more precise: the client
is already holding the control that asked, so it knows exactly
which one to give back.

}
\keyword{internal}
