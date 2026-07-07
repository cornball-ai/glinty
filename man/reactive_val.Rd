% tinyrox says don't edit this manually, but it can't stop you!
\name{reactive_val}
\alias{reactive_val}
\title{Create a reactive value}
\usage{
reactive_val(value = NULL)
}
\arguments{
\item{value}{initial value (default NULL)}
}
\value{
A function: rv() to get, rv(x) to set
}
\description{
A reactive value is a get/set container. Call with no arguments to
read (and register the current context as a dependent). Call with
one argument to write (and invalidate all dependents).
}
\examples{
rv <- reactive_val(1)
rv()
rv(2)
rv()
}
