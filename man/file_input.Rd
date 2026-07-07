% tinyrox says don't edit this manually, but it can't stop you!
\name{file_input}
\alias{file_input}
\title{Create a file input}
\usage{
file_input(id, label = "", accept = NULL, multiple = FALSE)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{accept}{character vector of accepted types/extensions,
e.g. c(".csv", "image/png") (optional)}

\item{multiple}{logical allow selecting several files}
}
\value{
A UI element
}
\description{
Files upload over a plain POST (not the WebSocket); when the
upload completes, the input value becomes a data.frame with one
row per file: name, size, type, datapath. The datapath points at
a server-side copy in a per-session temp dir removed when the
session ends. Size is capped by getOption("glinty.max_upload")
(10 MB default).
}
\examples{
file_input("dataset", "CSV:", accept = ".csv")
}
