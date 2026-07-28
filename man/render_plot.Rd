% tinyrox says don't edit this manually, but it can't stop you!
\name{render_plot}
\alias{render_plot}
\title{Render a base graphics plot}
\usage{
render_plot(fn, width = NULL, height = NULL, res = 72)
}
\arguments{
\item{fn}{zero-arg function that draws a plot}

\item{width}{integer logical-pixel width, or NULL for client-driven}

\item{height}{integer logical-pixel height, or NULL for
client-driven}

\item{res}{numeric PNG resolution (dpi) at dpr 1}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
Runs the plotting function against a PNG device and sends an
`image` output: `\{src, width, height\}`, dimensions in logical
pixels. With NULL width/height (the default) the plot sizes itself
to the client, which reports its box through `measure` messages on
first layout and on resize; the read is reactive, so a new
measurement re-renders the plot. Explicit numeric dimensions give
fixed-size rendering.
}
\details{
The client also reports its device pixel ratio, which applies to
fixed-size plots too. The raster is produced at `width * dpr` by
`height * dpr` physical pixels with `res` scaled by the same
factor, and displayed at the logical size: text and lines keep
their size while the pixels match the screen, which is what keeps
a plot sharp on a 2x display.

}
\examples{
\dontrun{
output$scatter <- render_plot(function() plot(rnorm(100)))
}
}
