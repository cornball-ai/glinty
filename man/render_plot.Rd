% tinyrox says don't edit this manually, but it can't stop you!
\name{render_plot}
\alias{render_plot}
\title{Render a base graphics plot}
\usage{
render_plot(fn, width = 480, height = 360, res = 72)
}
\arguments{
\item{fn}{zero-arg function that draws a plot}

\item{width}{integer pixel width}

\item{height}{integer pixel height}

\item{res}{numeric PNG resolution (dpi)}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
Runs the plotting function against a PNG device and patches the
output img's src with a data URI. Size is fixed at render time;
match it to plot_output()'s width and height.
}
\examples{
\dontrun{
output$scatter <- render_plot(function() plot(rnorm(100)))
}
}
