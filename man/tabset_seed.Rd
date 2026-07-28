% tinyrox says don't edit this manually, but it can't stop you!
\name{tabset_seed}
\alias{tabset_seed}
\title{Initial value of a tabset's selection input}
\usage{
tabset_seed(x)
}
\arguments{
\item{x}{a tabset component}
}
\value{
character panel title, or NULL
}
\description{
Only a tabset with an id has a selection the server tracks. The
selected title wins when it names a real panel; otherwise the
first panel is shown, which mirrors the lowering.
}
\keyword{internal}
