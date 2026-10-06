% tinyrox says don't edit this manually, but it can't stop you!
\name{component_ids}
\alias{component_ids}
\title{Every id in a component tree}
\usage{
component_ids(x)
}
\arguments{
\item{x}{a component, or a tree in its unclassed list form}
}
\value{
a character vector of ids, named by component kind
}
\description{
Walks a tree from \code{\link{page}} and friends, panels of a
tabset included, and returns every component's `id` in order of
appearance, named by component kind. A host mounting several
subtrees runs its collision check on this; \code{\link{app}} runs
its own.
}
\examples{
component_ids(column(text_input("name"), button("go", "Go"),
                     tabset(tab_panel("A", text_output("a")), id = "tabs")))
}
