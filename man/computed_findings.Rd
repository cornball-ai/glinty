% tinyrox says don't edit this manually, but it can't stop you!
\name{computed_findings}
\alias{computed_findings}
\title{Turn two measurements into findings}
\usage{
computed_findings(baseline, withapp)
}
\arguments{
\item{baseline}{list from computed_measure() without the app CSS}

\item{withapp}{list from computed_measure() with it}
}
\value{
character vector of findings
}
\description{
A finding is a property the baseline told apart and the app made
identical. The other direction -- an app introducing a distinction
glinty did not make -- is an app styling its variants, which is the
whole point of variants.
}
\keyword{internal}
