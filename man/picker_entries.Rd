% tinyrox says don't edit this manually, but it can't stop you!
\name{picker_entries}
\alias{picker_entries}
\title{The entries of a directory, as the picker shows them}
\usage{
picker_entries(dir, kind = "dir", pattern = NULL, hidden = FALSE)
}
\arguments{
\item{dir}{character directory path}

\item{kind}{"dir" or "file"}

\item{pattern}{character regex files must match, or NULL}

\item{hidden}{logical include dotfiles}
}
\value{
list(dirs, files) of bare names
}
\description{
Directories always list -- they are the way through -- and sort
case-insensitively. Files list only for kind = "file", filtered by
`pattern`. Dotfiles stay hidden unless asked for. A missing or
unreadable directory is empty rather than an error, so a listing
that raced a deletion degrades to "nothing in here".
}
\keyword{internal}
