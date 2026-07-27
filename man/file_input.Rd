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

\item{accept}{character vector of accepted types or extensions}

\item{multiple}{logical allow several files}
}
\value{
A UI component
}
\description{
Files upload over HTTP rather than the socket; when the upload
completes the input value becomes a data.frame with one row per
file: name, size, type, datapath.
}
\examples{
file_input("dataset", "CSV:", accept = ".csv")
}
