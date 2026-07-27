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
The value is set as innerHTML. component trees are serialized;
character values are trusted as-is, so escape untrusted text with
html_escape().
}
\examples{
\dontrun{
output$details <- render_html(function() div(h3("Result"), p("done")))
}
}
