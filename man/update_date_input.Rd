% tinyrox says don't edit this manually, but it can't stop you!
\name{update_date_input}
\alias{update_date_input}
\title{Update a date input from the server}
\usage{
update_date_input(session, id, value = NULL, min = NULL, max = NULL)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{value}{character new date, "YYYY-MM-DD"}

\item{min}{character new earliest selectable date}

\item{max}{character new latest selectable date}
}
\value{
invisible(NULL)
}
\description{
Update a date input from the server
}
\examples{
\dontrun{
update_date_input(session, "start", value = "2026-01-01")
}
}
