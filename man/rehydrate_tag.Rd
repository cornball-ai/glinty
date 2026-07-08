% tinyrox says don't edit this manually, but it can't stop you!
\name{rehydrate_tag}
\alias{rehydrate_tag}
\title{Rebuild a glinty_tag tree from parsed wire JSON}
\usage{
rehydrate_tag(x)
}
\arguments{
\item{x}{parsed JSON node (named list, character, or NULL)}
}
\value{
a glinty_tag, character, or NULL
}
\description{
render_ui() ships unclassed tag trees; the native side rebuilds
the class so translate_tag() can walk them like static UI.
}
\keyword{internal}
