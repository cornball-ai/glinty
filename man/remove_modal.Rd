% tinyrox says don't edit this manually, but it can't stop you!
\name{remove_modal}
\alias{remove_modal}
\title{Remove the open modal dialog}
\usage{
remove_modal(session)
}
\arguments{
\item{session}{a glinty_session}
}
\value{
invisible(NULL)
}
\description{
Closing an already-closed dialog is not an error.
}
\examples{
\dontrun{
observe_event(input$confirm, function() remove_modal(session))
}
}
