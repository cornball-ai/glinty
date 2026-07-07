% tinyrox says don't edit this manually, but it can't stop you!
\name{reactive}
\alias{reactive}
\title{Create a reactive expression}
\usage{
reactive(fn, label = "")
}
\arguments{
\item{fn}{a function with no arguments that computes the value}

\item{label}{character label for debugging}
}
\value{
A function: re() returns the (possibly cached) value
}
\description{
A reactive expression is a lazy, cached computation. It re-evaluates
only when an upstream source changes. Reading it registers the caller
as a dependent.
}
\examples{
rv <- reactive_val(5)
doubled <- reactive(function() rv() * 2)
doubled()
}
