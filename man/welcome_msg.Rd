% tinyrox says don't edit this manually, but it can't stop you!
\name{welcome_msg}
\alias{welcome_msg}
\title{Create the welcome message}
\usage{
welcome_msg(session_id, resumed = NULL)
}
\arguments{
\item{session_id}{character session ID}

\item{resumed}{logical TRUE when a detached session was resumed,
FALSE when a resume was refused (the client reloads), NULL for a
fresh session}
}
\value{
character JSON string
}
\description{
The bootstrap, and the first frame a client receives: the session
id, the protocol version, and the canonical component tree with
its revision. A client that ignores everything else and renders
welcome.ui is correct.
}
\details{
The tree and revision come from .globals, set once by run_app().
Both are omitted when unset (bare test sessions), never in a
served app.

}
\keyword{internal}
