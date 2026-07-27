% tinyrox says don't edit this manually, but it can't stop you!
\name{collect_input_seeds}
\alias{collect_input_seeds}
\title{Walk a component tree collecting seedable input values}
\usage{
collect_input_seeds(x)
}
\arguments{
\item{x}{a component or plain list tree}
}
\value{
named list of id -> initial value
}
\description{
Recurses through children and tabset panels; a hidden conditional
panel's inputs seed like any other, because hiding is display, not
existence.
}
\keyword{internal}
