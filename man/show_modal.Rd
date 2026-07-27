% tinyrox says don't edit this manually, but it can't stop you!
\name{show_modal}
\alias{show_modal}
\title{Show a modal dialog}
\usage{
show_modal(session, ..., title = NULL, footer = NULL, easy_close = TRUE)
}
\arguments{
\item{session}{a glinty_session}

\item{...}{body components}

\item{title}{character heading, or NULL}

\item{footer}{footer components; wrap several in row()}

\item{easy_close}{logical allow dismissing by backdrop or Escape}
}
\value{
invisible(NULL)
}
\description{
The body and footer are ordinary components, so inputs and buttons
inside them bind like any other UI: a button() in the footer sets
its input on press and the server decides what to do, including
calling remove_modal().
}
\details{
Only one dialog shows at a time; a second replaces the first.

}
\examples{
\dontrun{
show_modal(
    session,
    text("Download the model (6.2 GB)?"),
    title = "Download Model?",
    footer = row(modal_button("Cancel"), button("confirm", "Download"))
)
}
}
