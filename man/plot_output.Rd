% tinyrox says don't edit this manually, but it can't stop you!
\name{plot_output}
\alias{plot_output}
\title{Create a plot output placeholder}
\usage{
plot_output(id, width = NULL, height = NULL)
}
\arguments{
\item{id}{character output ID}

\item{width}{integer pixel width, or NULL for responsive}

\item{height}{integer pixel height, or NULL for responsive}
}
\value{
A UI element
}
\description{
An img element whose src is set to a PNG data URI by
render_plot(). With NULL width/height (the default) the element
fills its container at a 4:3 aspect ratio and the client reports
its rendered size, so render_plot(NULL, NULL) draws at the true
on-screen dimensions. Explicit dimensions give a fixed-size box;
match them to the renderer's.
}
\examples{
plot_output("scatter")
}
