% tinyrox says don't edit this manually, but it can't stop you!
\name{computed_findings}
\alias{computed_findings}
\title{Turn two measurements into findings}
\usage{
computed_findings(baseline, withapp, labels = character(0))
}
\arguments{
\item{baseline}{list from computed_measure() without the app CSS}

\item{withapp}{list from computed_measure() with it}

\item{labels}{named character: component -> the classes to name in
the message}
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
\details{
Both runs measure the same probe plan, so the two sets of keys must
match exactly. A key in one and not the other means a page failed
to render or the script stopped early, and every conclusion drawn
from a short measurement would be "no findings" -- the answer that
looks like success.

}
\keyword{internal}
