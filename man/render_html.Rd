% tinyrox says don't edit this manually, but it can't stop you!
\name{render_html}
\alias{render_html}
\title{Render HTML markup}
\usage{
render_html(fn)
}
\arguments{
\item{fn}{zero-arg function returning a component or character}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
Browser-only: the value is markup the browser inserts as-is.
Component trees are serialized; character values are trusted, so
escape untrusted text with html_escape().
}
\examples{
\dontrun{
output$details <- render_html(function() "<mark>done</mark>")
}
}
