% tinyrox says don't edit this manually, but it can't stop you!
\name{update_text_input}
\alias{update_text_input}
\title{Update a text input from the server}
\usage{
update_text_input(session, id, value = NULL, label = NULL, focus = FALSE)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{value}{character new value (NULL leaves it alone)}

\item{label}{character new label text (NULL leaves it alone)}

\item{focus}{logical move keyboard focus to this field (FALSE sends
nothing; there is no "unfocus" verb)}
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
\details{
`focus = TRUE` moves the keyboard focus to this field on arrival.
It is a one-shot verb, not state: focus lives in no tree, so the
message says "focus it now" and is spent. It applies even when some
other field is focused -- moving the caret is not the hazard the
never-stomp guard exists for (rewriting a draft is), and the app
asking to move the user's attention is the point. The case this
exists for: a composer that should be ready to type into after the
server swaps the layout, where the rebuilt DOM dropped focus with
the old tree.

}
\examples{
\dontrun{
update_text_input(session, "name", value = "Troy")
update_text_input(session, "draft", focus = TRUE)
}
}
