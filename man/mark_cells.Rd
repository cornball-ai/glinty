% tinyrox says don't edit this manually, but it can't stop you!
\name{mark_cells}
\alias{mark_cells}
\title{Mark table cells from inside the render function}
\usage{
mark_cells(df, ...)
}
\arguments{
\item{df}{the data.frame the render function returns}

\item{...}{marks named by column: a character vector of variants
from the [txt()] set, one per row, or one for the whole column.
`NA` and `"normal"` leave a cell plain}
}
\value{
`df`, with the marks attached for [render_table()]
}
\description{
The `variants =` rules read the rendered frame, so a mark that
depends on data the table does not show -- the replica count
behind a "serving 1/1" cell, the limit behind a memory column --
had no honest home, and an app ends up smuggling that data through
a side channel to reach it. This attaches the marks to the frame
itself, inside the render function, where the data is in scope:
the function that wrote the text writes its variant too.
}
\details{
Marks combine with `render_table(variants =)` column-wise; a
column marked from both places is refused rather than resolved,
because two authors for one column is a conflict, not a cascade.

}
\examples{
\dontrun{
output$services <- render_table(function() {
    svc <- services()
    mark_cells(data.frame(name = svc$name, serving = svc$label,
                          row.names = svc$name),
               serving = ifelse(svc$ready >= svc$replicas,
                                "success", "warning"))
})
}
}
