% tinyrox says don't edit this manually, but it can't stop you!
\name{translate_plot}
\alias{translate_plot}
\title{Translate a plot output}
\usage{
translate_plot(tg, values)
}
\arguments{
\item{tg}{the img glinty_tag}

\item{values}{output value env}
}
\value{
a flitR item
}
\description{
render_plot() values arrive as PNG data URIs; the base64 passes
straight into flitR's image op. Before the first render, a light
placeholder rect holds the space.
}
\keyword{internal}
