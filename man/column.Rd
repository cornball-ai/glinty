% tinyrox says don't edit this manually, but it can't stop you!
\name{column}
\alias{column}
\title{Arrange children in a vertical column}
\usage{
column(..., gap = NULL, grow = NULL, width = NULL, id = NULL)
}
\arguments{
\item{...}{child components}

\item{gap}{integer space between children, in pixels}

\item{grow}{integer share of the parent's spare space; 0 or NULL
takes none}

\item{width}{integer fixed width in pixels}

\item{id}{character element ID}
}
\value{
A UI component
}
\description{
Arrange children in a vertical column
}
\examples{
column(heading("Stack"), text_output("a"), text_output("b"))
}
