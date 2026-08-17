% tinyrox says don't edit this manually, but it can't stop you!
\name{path_within}
\alias{path_within}
\title{Is a path `root` itself, or inside it?}
\usage{
path_within(path, root)
}
\arguments{
\item{path,root}{character canonical paths}
}
\value{
logical
}
\description{
Both arguments must already be canonical (normalizePath). String
prefixing alone would call "/srv/data-evil" inside "/srv/data";
the appended separator is what makes containment mean containment.
}
\keyword{internal}
