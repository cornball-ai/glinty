% tinyrox says don't edit this manually, but it can't stop you!
\name{show_modal}
\alias{show_modal}
\title{Show a modal dialog}
\usage{
show_modal(
  session,
  ...,
  title = NULL,
  footer = NULL,
  easy_close = TRUE,
  size = c("default", "large")
)
}
\arguments{
\item{session}{a glinty_session}

\item{...}{body components}

\item{title}{character heading, or NULL}

\item{footer}{footer components; wrap several in row()}

\item{easy_close}{logical allow dismissing by backdrop or Escape}

\item{size}{"default" fits the content, up to a reading width;
"large" is a fixed, wider and taller dialog}
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

The title and footer stay put while a long body scrolls between
them. \code{size = "large"} asks for a dialog of fixed, generous
size -- a file browser, a long form -- so it neither grows and
shrinks with each step nor shrink-wraps a short listing.

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
