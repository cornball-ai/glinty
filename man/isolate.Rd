% tinyrox says don't edit this manually, but it can't stop you!
\name{isolate}
\alias{isolate}
\title{Run an expression without reactive tracking}
\usage{
isolate(expr)
}
\arguments{
\item{expr}{expression to evaluate}
}
\value{
the result of expr
}
\description{
Reads inside isolate() do not register as dependencies, so the
calling observer or expression will not re-run when those values
change.
}
\examples{
rv <- reactive_val(1)
isolate(rv())
}
