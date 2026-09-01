% tinyrox says don't edit this manually, but it can't stop you!
\name{render_table}
\alias{render_table}
\title{Render a data frame as a table}
\usage{
render_table(fn, variants = NULL, align = NULL)
}
\arguments{
\item{fn}{zero-arg function returning a data.frame}

\item{variants}{named list of per-column variant rules, or NULL}

\item{align}{named character vector of per-column alignment
overrides, `"left"` or `"right"`, or NULL}
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
\details{
Row names travel as `keys`, which is how a [data_table()] with
`selection` says which rows were chosen: `input$grid()` is a
character vector of keys, and `df[input$grid(), ]` is the selected
rows. Give the data.frame meaningful row names
(`row.names(df) <- df$run_id`) and a selection survives a re-sort
and a refresh; automatic row names (`"1"`, `"2"`, ...) work too,
as positions.

`variants` colors cells the way [txt()] colors text. A named list,
one entry per column, each entry one of: a single variant for the
whole column (`image = "mono"`); a named character vector looked up
by cell text (`state = c(failed = "danger", running = "success")`,
unmatched cells stay normal); or a function of the data.frame
returning one variant per row (`NA` or `"normal"` for none).
Semantic, never a color: what `danger` looks like is the theme's
decision, and a client draws it however it draws `txt("x", "danger")`.

A rule only sees the rendered frame. For a mark that depends on
data the table does not show -- the replica count behind a
"serving 1/1" cell, the limit behind a memory column -- attach the
marks to the frame with [mark_cells()] inside `fn`, where that data
is in scope. A column marked from both places is refused.

`align` overrides a column's alignment: a named character vector,
`"left"` or `"right"` per column. Numeric columns already
right-align and sort numerically; a pre-formatted string column
("1.2 GiB", "3m 12s") is text on the wire and sits left, so
`align = c(size = "right")` right-aligns it while keeping the
text sort -- calling it numeric instead would sort "1.2 GiB" as
1.2. `"right"` on a numeric column changes nothing; `"left"` on
one demotes it to text, presentation and sort together, because
the two travel as one signal.

}
\examples{
\dontrun{
output$results <- render_table(function() head(mtcars))
output$runs <- render_table(function() runs(),
    variants = list(state = c(failed = "danger", running = "success"),
                    image = "mono"))
output$fleet <- render_table(function() fleet(),
    align = c(memory = "right", age = "right"))
}
}
