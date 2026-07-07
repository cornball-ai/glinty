% tinyrox says don't edit this manually, but it can't stop you!
\name{serve_static}
\alias{serve_static}
\title{Serve a file from a static directory}
\usage{
serve_static(file_name, dir)
}
\arguments{
\item{file_name}{character path relative to dir}

\item{dir}{character directory to serve from}
}
\value{
raw HTTP response
}
\description{
Keeps browseR's traversal guard and MIME table.
}
\keyword{internal}
