% tinyrox says don't edit this manually, but it can't stop you!
\name{table_output}
\alias{table_output}
\title{Create a table output slot}
\usage{
table_output(id)
}
\arguments{
\item{id}{character output ID}
}
\value{
A UI component
}
\description{
The value travels as structure -- header plus rows -- rather than
markup, so each frontend draws it natively.
}
\examples{
table_output("results")
}
