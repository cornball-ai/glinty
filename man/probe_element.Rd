% tinyrox says don't edit this manually, but it can't stop you!
\name{probe_element}
\alias{probe_element}
\title{Tag one rendered component as a probe, in a forced state}
\usage{
probe_element(html, id, force = NULL)
}
\arguments{
\item{html}{character one component's HTML}

\item{id}{character probe id, read back by the page script}

\item{force}{character state class to add, or NULL}
}
\value{
character HTML
}
\description{
String surgery on markup, which is only safe because this is markup
glinty just produced: the outermost element is the component's own,
and it always carries a class. Both edits are checked rather than
assumed -- a lowering that stopped emitting a class attribute would
otherwise leave a probe that silently measures nothing.
}
\keyword{internal}
