% tinyrox says don't edit this manually, but it can't stop you!
\name{icon}
\alias{icon}
\title{Create an icon}
\usage{
icon(name, size = 16L)
}
\arguments{
\item{name}{character icon name, e.g. "play", "trash", "download"}

\item{size}{integer pixel size}
}
\value{
A UI component
}
\description{
The name is a token, not artwork: each frontend supplies its own
glyph. An unmapped name renders a visible placeholder rather than
nothing, so a typo shows up.
}
\examples{
icon("play")
}
