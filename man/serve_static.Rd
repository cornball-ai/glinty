% tinyrox says don't edit this manually, but it can't stop you!
\name{serve_static}
\alias{serve_static}
\title{Serve a file from a static directory}
\usage{
serve_static(file_name, dir, range = NULL)
}
\arguments{
\item{file_name}{character path relative to dir}

\item{dir}{character directory to serve from}

\item{range}{character `Range` header value, or NULL for the whole file}
}
\value{
raw HTTP response
}
\description{
Keeps browseR's traversal guard and MIME table, and answers byte-range
requests.
}
\details{
Ranges are what make a `<video>` seekable: without them the element
can play from the start but every scrub re-fetches the file, and the
whole thing passes through memory each time. Every response advertises
`Accept-Ranges: bytes`, because a client that is not told it can seek
will not try.

}
\keyword{internal}
