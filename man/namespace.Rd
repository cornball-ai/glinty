% tinyrox says don't edit this manually, but it can't stop you!
\name{namespace}
\alias{namespace}
\title{An id builder for one subtree}
\usage{
namespace(name, parent = NULL)
}
\arguments{
\item{name}{a short word: letters, digits and underscores, starting
with a letter}

\item{parent}{another namespace to nest under, so the prefix is
`parent_name_`}
}
\value{
a function(id) prefixing ids, of class `glinty_namespace`;
  called with no argument it returns the prefix
}
\description{
`ns <- namespace("stt")` makes `ns("file")` return `"stt_file"`.
Build a subtree's UI with it, and hand its server code the proxies
from \code{\link{scoped}} so `input$file` reads the same id.
}
\examples{
ns <- namespace("stt")
ns("file")
ns(c("go", "stop"))
ns()
inner <- namespace("logs", parent = ns)
inner("tail")
}
