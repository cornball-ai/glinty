% tinyrox says don't edit this manually, but it can't stop you!
\name{collapse}
\alias{collapse}
\title{A section the user can fold away}
\usage{
collapse(..., title, open = FALSE, id = NULL)
}
\arguments{
\item{...}{child components}

\item{title}{character the always-visible summary line}

\item{open}{logical start unfolded}

\item{id}{character element ID}
}
\value{
A UI component
}
\description{
`<details>` in the browser, an `ExpansionTile` in Flutter: the
interaction is native to both, so nothing has to be rebuilt out of
a button and a hidden div.
}
\examples{
collapse(slider_input("speed", "Speed", 0.5, 2), title = "Parameters")
}
