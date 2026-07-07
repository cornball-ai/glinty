% tinyrox says don't edit this manually, but it can't stop you!
\name{req}
\alias{req}
\title{Require truthy values}
\usage{
req(...)
}
\arguments{
\item{...}{values to require}
}
\value{
the first argument, invisibly, if all are truthy
}
\description{
Aborts the current observer or renderer silently (no error message,
no output update) if any argument is not truthy: NULL, empty,
all-NA, FALSE, or an empty string. Mirrors Shiny's req().
}
\examples{
rv <- reactive_val(NULL)
obs <- observe(function() {
    req(rv())
    message("only reached once rv is truthy")
})
}
