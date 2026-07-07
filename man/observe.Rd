% tinyrox says don't edit this manually, but it can't stop you!
\name{observe}
\alias{observe}
\title{Create an observer}
\usage{
observe(fn, priority = 0L, label = "")
}
\arguments{
\item{fn}{a function with no arguments that performs side effects}

\item{priority}{numeric priority (higher runs first, default 0)}

\item{label}{character label for debugging}
}
\value{
Invisibly, an environment with a $destroy() method
}
\description{
An observer is a side-effect that re-runs whenever its reactive
dependencies change. Unlike reactive expressions, observers are
eager: they execute on the next flush, not when read.
}
\examples{
rv <- reactive_val("x")
obs <- observe(function() message(rv()))
obs$destroy()
}
