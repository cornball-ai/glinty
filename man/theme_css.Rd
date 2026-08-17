% tinyrox says don't edit this manually, but it can't stop you!
\name{theme_css}
\alias{theme_css}
\title{Serialize a theme as CSS}
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
client re-applies them, so a cached page self-heals. A theme with
a dark palette adds a prefers-color-scheme block after the :root
block -- the same shape the stylesheet's own dark mode has, in the
same style element, so precedence over the stylesheet and under
app CSS is unchanged.
}
\keyword{internal}
