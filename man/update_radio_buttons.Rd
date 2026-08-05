% tinyrox says don't edit this manually, but it can't stop you!
\name{update_radio_buttons}
\alias{update_radio_buttons}
\title{Update a radio button group from the server}
\usage{
update_radio_buttons(
  session,
  id,
  choices = NULL,
  selected = NULL,
  label = NULL
)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{choices}{character vector of choices; names are display
labels (NULL leaves them alone)}

\item{selected}{character value to check (NULL leaves it alone,
unless choices are replaced, in which case the first choice is
checked)}

\item{label}{character new group label text}
}
\value{
invisible(NULL)
}
\description{
Update a radio button group from the server
}
\examples{
\dontrun{
update_radio_buttons(session, "mode", selected = "careful")
}
}
