% tinyrox says don't edit this manually, but it can't stop you!
\name{panel_env}
\alias{panel_env}
\title{A session's panel map, from the static tree}
\usage{
panel_env(ui)
}
\arguments{
\item{ui}{the app's UI tree}
}
\value{
an environment, id -> conditions
}
\description{
One environment per session, because a dynamic subtree adds to it
at render time and sessions render different subtrees.
}
\keyword{internal}
