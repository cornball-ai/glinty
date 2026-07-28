% tinyrox says don't edit this manually, but it can't stop you!
\name{row}
\alias{row}
\title{Arrange children in a horizontal row}
\usage{
row(..., gap = NULL, align = NULL, grow = NULL, width = NULL, id = NULL)
}
\arguments{
\item{...}{child components}

\item{gap}{integer space between children, in pixels}

\item{align}{character "start", "center" or "end"}

\item{grow}{integer share of the parent's spare space; 0 or NULL
takes none. A row of one grown child and one fixed-width child is
the sidebar-plus-content shape}

\item{width}{integer fixed width in pixels}

\item{id}{character element ID}
}
\value{
A UI component
}
\description{
Note: masks base::row() (matrix row indices) when glinty is
attached, the same way page() masks utils::page(); call base::row()
qualified if you need it.
}
\examples{
row(button("a", "A"), button("b", "B"), gap = 12L)
}
