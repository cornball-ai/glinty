% tinyrox says don't edit this manually, but it can't stop you!
\name{update_number_input}
\alias{update_number_input}
\title{Update a numeric input from the server}
\usage{
update_number_input(session, id, value = NULL, min = NULL, max = NULL,
                    step = NULL)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character input ID}

\item{value}{numeric new value}

\item{min}{numeric new minimum}

\item{max}{numeric new maximum}

\item{step}{numeric new step}
}
\value{
invisible(NULL)
}
\description{
Update a numeric input from the server
}
\examples{
\dontrun{
update_number_input(session, "k", value = 5)
}
}
