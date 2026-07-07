% tinyrox says don't edit this manually, but it can't stop you!
\name{render_plot}
\alias{render_plot}
\title{Render a base graphics plot}
\usage{
render_plot(fn, width = NULL, height = NULL, res = 72)
}
\arguments{
\item{fn}{zero-arg function that draws a plot}

\item{width}{integer pixel width, or NULL for client-driven}

\item{height}{integer pixel height, or NULL for client-driven}

\item{res}{numeric PNG resolution (dpi)}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
Runs the plotting function against a PNG device and patches the
output img's src with a data URI. With NULL width/height (the
default) the plot sizes itself to the client: the browser reports
the rendered img box as reserved inputs and re-reports on window
resize, so the plot re-renders reactively at the new size.
Explicit numeric dimensions give fixed-size rendering.
}
\examples{
\dontrun{
output$scatter <- render_plot(function() plot(rnorm(100)))
}
}
