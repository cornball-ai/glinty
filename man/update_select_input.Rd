% tinyrox says don't edit this manually, but it can't stop you!
\name{update_select_input}
\alias{update_select_input}
\title{Update a select input from the server}
\usage{
update_select_input(session, id, choices = NULL, selected = NULL, label = NULL)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{choices}{character vector of choices; names are display
labels (NULL leaves them alone)}

\item{selected}{character value to select (NULL leaves it alone,
unless choices are replaced, in which case the first choice is
selected)}

\item{label}{character new label text}
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
}
}
