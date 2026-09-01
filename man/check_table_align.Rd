% tinyrox says don't edit this manually, but it can't stop you!
\name{check_table_align}
\alias{check_table_align}
\title{Refuse a malformed `align` where render_table() was written}
\usage{
check_table_align(align)
}
\arguments{
\item{align}{the render_table(align =) argument}
}
\value{
invisible NULL, or an error
}
\description{
The shape and the values are static, so both are checked at
definition. Whether the named columns exist can only be known
against a frame, so that half waits for the render and surfaces
as the output's error.
}
\keyword{internal}
