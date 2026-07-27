% tinyrox says don't edit this manually, but it can't stop you!
\name{update_text_input}
\alias{update_text_input}
\title{Update a text input from the server}
\usage{
update_text_input(session, id, value = NULL, label = NULL)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{value}{character new value (NULL leaves it alone)}

\item{label}{character new label text (NULL leaves it alone)}
}
\value{
invisible(NULL)
}
\description{
Sends a typed input_update message that the client applies without
re-emitting an input event, and syncs the session's server-side
input value so state converges without a round trip. The client
skips the value patch when the element has focus, so it never
stomps live typing.
}
\examples{
\dontrun{
update_text_input(session, "name", value = "Troy")
}
}
