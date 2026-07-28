% tinyrox says don't edit this manually, but it can't stop you!
\name{select_seed}
\alias{select_seed}
\title{Initial value of a select input}
\usage{
select_seed(x)
}
\arguments{
\item{x}{a select_input component}
}
\value{
character value, or NULL
}
\description{
A single select displays its first choice when nothing is
selected, so that is its value.
}
\details{
A multiple select with nothing selected has an empty selection,
which is a character(0) rather than a NULL. The browser harvests
`Array.from(el.selectedOptions)` and gets `[]`, so seeding NULL
here made the server disagree with the client it is mirroring
before a single interaction had happened.

}
\keyword{internal}
