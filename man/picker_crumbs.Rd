% tinyrox says don't edit this manually, but it can't stop you!
\name{picker_crumbs}
\alias{picker_crumbs}
\title{The path split into the pieces you can jump back to, root first}
\usage{
picker_crumbs(dir, root = NULL)
}
\arguments{
\item{dir}{character directory path}

\item{root}{character topmost crumb, or NULL for the filesystem root}
}
\value{
data.frame(name, path)
}
\description{
What makes going up four levels one press instead of four. Stops
at `root` when one is set, so the crumbs never offer a step the
navigation would refuse.
}
\keyword{internal}
