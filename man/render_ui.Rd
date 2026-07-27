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
(wrap several in div()/column()) or NULL to render nothing. The
tag tree travels structured on the wire; the browser builds real
DOM from it (event bindings included, via delegation) and the
native backend translates it like static UI. Inputs that first
appear inside dynamic UI start as NULL server-side until the user
touches them, on both frontends. For raw markup strings use
render_html() (browser-only escape hatch).
}
\examples{
\dontrun{
output$panel <- render_ui(function() {
    if (isTRUE(input$show())) div(text_input("extra", "Extra:"))
})
}
}
