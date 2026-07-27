% tinyrox says don't edit this manually, but it can't stop you!
\name{theme_css}
\alias{theme_css}
\title{Serialize a theme as a :root CSS block}
\usage{
theme_css(th)
}
\arguments{
\item{th}{a glinty_theme}
}
\value{
character CSS
}
\description{
Emitted into the served document so the first paint is themed
before any socket work; welcome repeats the same tokens and the
client re-applies them, so a cached page self-heals.
}
\keyword{internal}
