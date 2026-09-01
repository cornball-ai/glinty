% tinyrox says don't edit this manually, but it can't stop you!
\name{cell_variants}
\alias{cell_variants}
\title{Resolve per-column variant rules to one mark per cell}
\usage{
cell_variants(df, cols, variants)
}
\arguments{
\item{df}{the data.frame being rendered}

\item{cols}{its columns as character, the cell text a lookup reads}

\item{variants}{the checked render_table(variants =) argument}
}
\value{
NULL when nothing is marked, else a list (one per column)
  of character vectors with NA for an unmarked cell
}
\description{
Resolve per-column variant rules to one mark per cell
}
\keyword{internal}
