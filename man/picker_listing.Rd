% tinyrox says don't edit this manually, but it can't stop you!
\name{picker_listing}
\alias{picker_listing}
\title{The listing as the dialog's table shows it}
\usage{
picker_listing(dir, entries)
}
\arguments{
\item{dir}{character the directory, canonical}

\item{entries}{list(dirs, files) of bare names}
}
\value{
data.frame(Name, Kind, Modified, Size)
}
\description{
One row per entry, folders first: the name, what it is (a folder,
or the file's extension), when it changed and, for a file, how big
it is. The row names are the absolute paths, which is what a row
click reports back as the table's key.
}
\keyword{internal}
