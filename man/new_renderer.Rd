% tinyrox says don't edit this manually, but it can't stop you!
\name{new_renderer}
\alias{new_renderer}
\title{Construct a renderer}
\usage{
new_renderer(fn, kind)
}
\arguments{
\item{fn}{zero-arg function producing the client-ready value}

\item{kind}{character what the value is (text, html, table, image,
audio, ui) -- the `kind` field of the output message it feeds}
}
\value{
a glinty_renderer
}
\description{
Construct a renderer
}
\keyword{internal}
