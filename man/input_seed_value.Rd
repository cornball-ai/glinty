% tinyrox says don't edit this manually, but it can't stop you!
\name{input_seed_value}
\alias{input_seed_value}
\title{The initial value one input component contributes}
\usage{
input_seed_value(x)
}
\arguments{
\item{x}{a component (or its unclassed list form)}
}
\value{
an initial value, or NULL
}
\description{
Mirrors what a browser would have harvested from the rendered
control, because that is the state the user actually sees:
an empty text field is "", an untouched checkbox is FALSE, a
single select shows its first choice, a multiple select with
nothing chosen is character(0), a slider with no value sits at the
midpoint (the HTML default). NULL means this component seeds
nothing and the input stays auto-NULL: an empty number field,
every button and output.
}
\keyword{internal}
