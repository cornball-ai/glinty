% tinyrox says don't edit this manually, but it can't stop you!
\name{data_table}
\alias{data_table}
\title{Create an interactive table output slot}
\usage{
data_table(
  id,
  page_length = 10L,
  length_menu = c(10, 25, 50, 100),
  searchable = TRUE,
  sortable = TRUE,
  selection = "none"
)
}
\arguments{
\item{id}{character output ID}

\item{page_length}{integer rows shown per page}

\item{length_menu}{numeric page-size options offered}

\item{searchable}{logical show the filter box}

\item{sortable}{logical allow header-click sorting}

\item{selection}{character "none", "single" or "multiple": whether
rows can be selected, and how many at once}
}
\value{
A UI component
}
\description{
Takes the same table value as [table_output()] -- header, rows,
alignment -- and adds client-side sorting, filtering and
pagination. Interaction never touches the server: the client
holds the whole value and rearranges it locally, so sort state
lives where the click happened and a re-rendered value keeps the
reader's page when it still exists. Numeric columns (the
alignment the wire already carries) sort numerically; the rest
sort as text. Feed it with [render_table()] like any table; keep
the value at a size a client comfortably holds -- sample or
pre-filter server-side above a few thousand rows.
}
\details{
Given a `selection`, the table is also an input: `input[[id]]` is
the character vector of selected row keys -- the data.frame's
`row.names()`, which [render_table()] sends as `keys` -- and
`character(0)` when nothing is selected, so `df[input$grid(), ]`
is the selected rows. `"single"` replaces the selection on each
click and clears it on a second click of the same row;
`"multiple"` toggles rows. Keys are reported in data order, not
click order, and a row that leaves the value leaves the selection.
Sorting and filtering stay local, so a selected row stays selected
through both.

A cleared selection arrives as `character(0)`, not `NULL`. An
[observe_event()] with the default `ignore_null = TRUE` skips it,
which suits a detail pane holding the last opened row; watch with
`ignore_null = FALSE` to react to the clear itself.

}
\examples{
data_table("results", page_length = 5)
data_table("runs", selection = "single")
}
