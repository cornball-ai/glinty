% tinyrox says don't edit this manually, but it can't stop you!
\name{update_select_input}
\alias{update_select_input}
\title{Update a select input from the server}
\usage{
update_select_input(
  session,
  id,
  choices = NULL,
  selected = NULL,
  label = NULL,
  multiple = NULL
)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{choices}{character vector of choices; names are display
labels (NULL leaves them alone)}

\item{selected}{character value(s) to select (NULL leaves it
alone, unless choices are replaced, in which case the first
choice is selected). More than one value means a multiple
select, and is sent as an array}

\item{label}{character new label text}

\item{multiple}{logical whether this control is a multiple select.
Only needed to send one or zero selections to one: the wire form
of `selected` is an array at every length there, and a length-1
vector cannot say on its own which it meant}
}
\value{
invisible(NULL)
}
\description{
Update a select input from the server
}
\examples{
\dontrun{
update_select_input(session, "engine", choices = c("a", "b"))
update_select_input(session, "tags", selected = c("a", "c"))
update_select_input(session, "tags", selected = "a", multiple = TRUE)
}
}
