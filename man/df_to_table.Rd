% tinyrox says don't edit this manually, but it can't stop you!
\name{df_to_table}
\alias{df_to_table}
\title{Convert a data.frame to the wire table structure}
\usage{
df_to_table(df, variants = NULL)
}
\arguments{
\item{df}{a data.frame}

\item{variants}{per-column variant rules, see [render_table()]}
}
\value{
list(header, rows, keys, align)
}
\description{
I() wrappers keep length-1 headers, keys and single-cell rows as
JSON arrays under auto_unbox. `align` marks each column "num" or
"text": values become strings on the wire, so numeric-ness must
travel alongside or the frontends can't right-align numbers.
`keys` are the row names, what a selectable table reports.
}
\details{
A cell is a string, or `list(text =, variant =)` when a variant
rule marked it -- only the marked cells change shape, so a table
with no rules is byte-for-byte what it always was, and a client
that has never heard of the object form shows it as an object
rather than as a plausible string.

}
\keyword{internal}
