% tinyrox says don't edit this manually, but it can't stop you!
\name{render_ui}
\alias{render_ui}
\title{Render a dynamic UI subtree}
\usage{
render_ui(fn)
}
\arguments{
\item{fn}{zero-arg function returning a component or NULL}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
The portable path for dynamic content: fn returns a component
(wrap several in column() or row()) or NULL to render nothing. The
component tree travels structured on the wire, so every frontend
builds it the way it builds static UI -- the browser as real DOM,
event bindings included via delegation. Inputs that first appear
inside dynamic UI start as NULL server-side until the user touches
them. For raw markup strings use render_html(), which is a
browser-only escape hatch.
}
\examples{
\dontrun{
output$panel <- render_ui(function() {
    if (isTRUE(input$show())) column(text_input("extra", "Extra:"))
})
}
}
