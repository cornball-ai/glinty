% tinyrox says don't edit this manually, but it can't stop you!
\name{plot_output}
\alias{plot_output}
\title{Create a plot output placeholder}
\usage{
plot_output(id, width = 480L, height = 360L)
}
\arguments{
\item{id}{character output ID}

\item{width}{integer pixel width}

\item{height}{integer pixel height}
}
\value{
A UI element
}
\description{
An img element whose src is set to a PNG data URI by
render_plot(). Width and height should match the renderer.
}
\examples{
plot_output("scatter", width = 480L, height = 360L)
}
