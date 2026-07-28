% tinyrox says don't edit this manually, but it can't stop you!
\name{plot_output}
\alias{plot_output}
\title{Create a plot output slot}
\usage{
plot_output(id, width = NULL, height = NULL, alt = "")
}
\arguments{
\item{id}{character output ID}

\item{alt}{character alternative text}

\item{width,height}{integer pixel size, or NULL for client-sized}
}
\value{
A UI component
}
\description{
With NULL dimensions the slot fills its container and the client
reports its rendered box back, so render_plot() can draw at the true
on-screen size. Explicit dimensions give a fixed box, which is what
a client that cannot measure itself needs.
}
\examples{
plot_output("scatter")
plot_output("fixed", width = 400L, height = 300L)
}
