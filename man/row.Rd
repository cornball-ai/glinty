% tinyrox says don't edit this manually, but it can't stop you!
\name{row}
\alias{row}
\title{Arrange children in a horizontal row}
\usage{
row(..., gap = NULL, align = NULL)
}
\arguments{
\item{...}{child elements}

\item{gap}{numeric gap between children in pixels (frontend
default when NULL)}

\item{align}{character vertical alignment: "start", "center", or
"end" (browser only)}
}
\value{
A UI element
}
\description{
Maps to a flexbox row in the browser and flitR's row layout in the
native backend, so layouts carry across frontends. Note: masks
base::row() (matrix row indices) when glinty is attached, the same
way page() masks utils::page(); call base::row() qualified if you
need it.
}
\examples{
row(button("a", "A"), button("b", "B"), gap = 24)
}
