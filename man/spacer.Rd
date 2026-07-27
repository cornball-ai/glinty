% tinyrox says don't edit this manually, but it can't stop you!
\name{spacer}
\alias{spacer}
\title{Create empty space}
\usage{
spacer(size = 1L)
}
\arguments{
\item{size}{integer multiples of the theme's spacing unit}
}
\value{
A UI component
}
\description{
Sized in theme spacing units rather than pixels, so it scales with
the theme instead of pinning a frontend to CSS lengths.
}
\examples{
spacer(2L)
}
