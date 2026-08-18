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
  sortable = TRUE
)
}
\arguments{
\item{id}{character output ID}

\item{page_length}{integer rows shown per page}

\item{length_menu}{numeric page-size options offered}

\item{searchable}{logical show the filter box}

\item{sortable}{logical allow header-click sorting}
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
\examples{
data_table("results", page_length = 5)
}
