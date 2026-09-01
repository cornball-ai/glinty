% tinyrox says don't edit this manually, but it can't stop you!
\name{check_cell_variants}
\alias{check_cell_variants}
\title{Refuse a variant outside the text set}
\usage{
check_cell_variants(v, col)
}
\arguments{
\item{v}{character variants, NA allowed for an unmarked cell}

\item{col}{the column the rule belongs to, for the message}
}
\value{
invisible NULL, or an error naming the bad variants
}
\description{
Refuse a variant outside the text set
}
\keyword{internal}
