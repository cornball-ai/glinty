% tinyrox says don't edit this manually, but it can't stop you!
\name{serve_mounted}
\alias{serve_mounted}
\title{Serve a path under /static/ from the mounts}
\usage{
serve_mounted(path, mounts, range = NULL)
}
\arguments{
\item{path}{character the request path after /static/}

\item{mounts}{a mount vector from static_mounts()}

\item{range}{character `Range` header value, or NULL}
}
\value{
raw HTTP response
}
\description{
A named mount claims its first path segment; the root mount, when
there is one, takes whatever no name claims. A named mount shadows
a root directory of the same name, which is the documented order.
The traversal guard is serve_static()'s.
}
\keyword{internal}
