% tinyrox says don't edit this manually, but it can't stop you!
\name{render_table}
\alias{render_table}
\title{Render a data frame as a table}
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
The wire carries structure (header + rows of strings), not markup:
the browser client builds the table via DOM (textContent per cell,
so escaping is structurally unnecessary) and the native frontend
draws a grid from the same data.
}
\examples{
\dontrun{
output$results <- render_table(function() head(mtcars))
}
}
