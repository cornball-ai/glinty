% tinyrox says don't edit this manually, but it can't stop you!
\name{md_inline}
\alias{md_inline}
\title{Parse inline markdown into flat runs}
\usage{
md_inline(s)
}
\arguments{
\item{s}{character the inline source}
}
\value{
list of runs (lists with text and marks)
}
\description{
A sequential scanner: literal text up to the next delimiter, then
the delimiter's span with its mark added, recursively -- but the
OUTPUT is flat, because marks travel as state. An opener with no
closer is literal text. Backslash escapes the delimiter set.
Adjacent runs with identical marks merge, so the wire form is
canonical however the nesting was written.
}
\keyword{internal}
