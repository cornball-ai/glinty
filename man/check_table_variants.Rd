% tinyrox says don't edit this manually, but it can't stop you!
\name{check_table_variants}
\alias{check_table_variants}
\title{Refuse a malformed `variants` where render_table() was written}
\usage{
check_table_variants(variants)
}
\arguments{
\item{variants}{the render_table(variants =) argument}
}
\value{
invisible NULL, or an error
}
\description{
The static forms (a variant, a lookup vector) are checked here so
a typo fails at definition, not on the first render. A function
rule can only be checked against what it returns, so that half
waits for the render and surfaces as the output's error.
}
\keyword{internal}
