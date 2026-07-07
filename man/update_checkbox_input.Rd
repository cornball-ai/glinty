% tinyrox says don't edit this manually, but it can't stop you!
\name{update_checkbox_input}
\alias{update_checkbox_input}
\title{Update a checkbox input from the server}
\usage{
update_checkbox_input(session, id, value = NULL, label = NULL)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{value}{logical new checked state}

\item{label}{character new label text}
}
\value{
invisible(NULL)
}
\description{
Update a checkbox input from the server
}
\examples{
\dontrun{
update_checkbox_input(session, "save", value = TRUE)
}
}
