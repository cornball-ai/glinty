% tinyrox says don't edit this manually, but it can't stop you!
\name{translate_table}
\alias{translate_table}
\title{Draw a structured table as a native grid}
\usage{
translate_table(tg, values)
}
\arguments{
\item{tg}{the table_output div tag}

\item{values}{output value env}
}
\value{
list of flitR ops, or NULL before the first update
}
\description{
Consumes the wire table format (\{header, rows\}) stored by
native_apply. Column widths from a character-count heuristic;
text self-corrects via flitR's measurement cache like all native
text. Empty until the first update arrives.
}
\keyword{internal}
