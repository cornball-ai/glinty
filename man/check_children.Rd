% tinyrox says don't edit this manually, but it can't stop you!
\name{check_children}
\alias{check_children}
\title{Coerce a list of children, rejecting anything that is not a component}
\usage{
check_children(children, fn)
}
\arguments{
\item{children}{list of candidate children}

\item{fn}{character calling function, for the error message}
}
\value{
the list, unnamed
}
\description{
Layout components accept `...` and every element has to be a
component, or a lowering will meet something it cannot render at the
worst possible moment. Catching it here names the caller instead.
}
\keyword{internal}
