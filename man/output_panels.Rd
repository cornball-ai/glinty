% tinyrox says don't edit this manually, but it can't stop you!
\name{output_panels}
\alias{output_panels}
\title{Which tab panels enclose each id}
\usage{
output_panels(x, base = list())
}
\arguments{
\item{x}{a component, or a tree in its unclassed list form}

\item{base}{conditions already enclosing `x` (a dynamic subtree
inherits its slot's)}
}
\value{
a named list, id -> list of list(tabset =, panel =)
}
\description{
Walks a tree and, for every component with an id inside a panel of
a tabset, records the (tabset id, panel title) pairs that must all
be open for it to be visible. Nested tabsets stack their
conditions. Ids outside any panel are not recorded: nothing hides
them.
}
\keyword{internal}
