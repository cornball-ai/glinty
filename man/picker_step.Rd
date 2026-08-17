% tinyrox says don't edit this manually, but it can't stop you!
\name{picker_step}
\alias{picker_step}
\title{One navigation step, canonicalized and bounded}
\usage{
picker_step(cur, target, root = NULL)
}
\arguments{
\item{cur}{character current directory (canonical)}

\item{target}{character proposed directory}

\item{root}{character boundary, or NULL for none}
}
\value{
character the new current directory
}
\description{
Button values arrive from the client, so no target is trusted:
anything that is not an existing directory leaves the picker where
it stands, and canonicalizing before the root check means a ".."
or a symlink pointing out of `root` is refused, not followed.
}
\keyword{internal}
