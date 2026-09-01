% tinyrox says don't edit this manually, but it can't stop you!
\name{key_value}
\alias{key_value}
\title{Create a key/value list}
\usage{
key_value(items, id = NULL)
}
\arguments{
\item{items}{a named character vector, or a named list whose values
are strings, numbers or [txt()] components}

\item{id}{character element ID}
}
\value{
A UI component
}
\description{
Pairs, one per line: a run's image digest, its node, its ports.
The keys are the names of `items`; a value is a string (or a
number), or a [txt()] so it can carry a variant --
`txt(digest, "mono")`, `txt("failed", "danger")`. A `<dl>` in the
browser and a two-column table in Flutter, so nothing is rebuilt
out of rows of two texts with a width on each.
}
\details{
For pairs that change, build it inside [render_ui()] like any other
tree. An empty `items` renders an empty block: for a slot with
nothing to show yet that is a state, not an error.

}
\examples{
key_value(c(Node = "troy-g5", Replicas = "1"))
key_value(list(Image = txt("sha256:8b21e4", "mono"),
               State = txt("failed", "danger")))
}
