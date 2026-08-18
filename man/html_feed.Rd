% tinyrox says don't edit this manually, but it can't stop you!
\name{html_feed}
\alias{html_feed}
\title{The feed shell: an empty scroller the messages fill}
\usage{
html_feed(x)
}
\arguments{
\item{x}{the component}
}
\value{
character HTML
}
\description{
Items live in .g-feed-items; the jump button sits after them and
sticks to the bottom edge of the scroller, hidden until the reader
scrolls away from the bottom while items arrive. data-g-keep is the
declaration; the effective bound rides every feed message, which is
what the client trims by.
}
\keyword{internal}
