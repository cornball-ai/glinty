% tinyrox says don't edit this manually, but it can't stop you!
\name{df_to_table}
\alias{df_to_table}
\title{Convert a data.frame to the wire table structure}
\usage{
df_to_table(df)
}
\arguments{
\item{df}{a data.frame}
}
\value{
list(header, rows) of character vectors
}
\description{
I() wrappers keep length-1 headers and single-cell rows as JSON
arrays under auto_unbox.
}
\keyword{internal}
