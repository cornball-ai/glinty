% tinyrox says don't edit this manually, but it can't stop you!
\name{show_modal}
\alias{show_modal}
\title{Show a modal dialog}
\usage{
show_modal(session, ..., title = NULL, footer = NULL, easy_close = TRUE)
}
\arguments{
\item{session}{a glinty_session}

\item{...}{body elements}

\item{title}{character heading, or NULL for none}

\item{footer}{footer elements, typically buttons; wrap several in
row() or div()}

\item{easy_close}{logical allow dismissing by clicking the
backdrop or pressing Escape}
}
\value{
invisible(NULL)
}
\description{
Sends a dialog the client builds and overlays. The body and footer
are ordinary tag trees, so inputs and buttons inside them bind like
any other UI: a button() in the footer sets its input on click and
the server decides what to do, including calling remove_modal().
}
\details{
The dialog is mounted inside #glinty-root, so event delegation
reaches it. Only one dialog is shown at a time; showing a second
replaces the first.

Browser-only: the native backend ignores modal messages.

}
\examples{
\dontrun{
show_modal(
    session,
    p("Download the 'large-v3' model (6.2 GB) from HuggingFace?"),
    title = "Download Model?",
    footer = row(modal_button("Cancel"), button("confirm", "Download"))
)
}
}
