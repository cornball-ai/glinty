% tinyrox says don't edit this manually, but it can't stop you!
\name{html_flex_style}
\alias{html_flex_style}
\title{Inline style for a container's share of its parent}
\usage{
html_flex_style(x)
}
\arguments{
\item{x}{the component}
}
\value{
character style fragment, or NULL
}
\description{
`grow` and `width` are numbers on both sides of the wire; this is
the only place they become CSS. flex-grow with a zero basis is what
makes "fill the rest" behave the same whatever the content is,
which is the whole reason the field exists.
}
\keyword{internal}
