% tinyrox says don't edit this manually, but it can't stop you!
\name{html_prompter}
\alias{html_prompter}
\title{The prompter, with its words in place and its bar at rest}
\usage{
html_prompter(x)
}
\arguments{
\item{x}{the component}
}
\value{
character HTML
}
\description{
The same DOM the client builds (buildPrompter in glinty.js): the
stage holds the scrolling view and the reading-line marker beside
it, so the marker stays put while the words move; the bar below is
the client's own chrome, not vocabulary. Settings ride as data-g-*
so an adopted page starts where the tree says; everything that
moves is state the client creates on first touch.
}
\keyword{internal}
