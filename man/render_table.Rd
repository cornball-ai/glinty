% tinyrox says don't edit this manually, but it can't stop you!
\name{render_table}
\alias{render_table}
\title{Render a data frame as an HTML table}
\usage{
render_table(fn)
}
\arguments{
\item{fn}{zero-arg function returning a data.frame}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
Cell contents are escaped.
}
\examples{
\dontrun{
output$results <- render_table(function() head(mtcars))
}
}
