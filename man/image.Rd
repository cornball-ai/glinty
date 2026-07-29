% tinyrox says don't edit this manually, but it can't stop you!
\name{image}
\alias{image}
\title{A picture that is part of the UI}
\usage{
image(src, alt = "", width = NULL, height = NULL)
}
\arguments{
\item{src}{character URL or data URI}

\item{alt}{character alternative text}

\item{width,height}{integer pixel size}
}
\value{
A UI component
}
\description{
For a logo or a static illustration. An image the *server* produces
is `image_output()` plus `render_plot()` or `render_image()`; this
is the one that is simply there.
}
\examples{
image("/static/logo.png", alt = "cornball.ai", width = 32L)
}
