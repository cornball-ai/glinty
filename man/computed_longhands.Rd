% tinyrox says don't edit this manually, but it can't stop you!
\name{computed_longhands}
\alias{computed_longhands}
\title{The longhand properties a shorthand resolves to}
\usage{
computed_longhands(props)
}
\arguments{
\item{props}{character properties as written in the stylesheet}
}
\value{
character longhand property names
}
\description{
getComputedStyle() answers for longhands; a stylesheet writes
shorthands. Reading `background` back would compare a string the
browser assembles rather than the values that actually differ.
}
\keyword{internal}
