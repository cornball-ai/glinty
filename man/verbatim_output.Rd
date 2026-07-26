% tinyrox says don't edit this manually, but it can't stop you!
\name{verbatim_output}
\alias{verbatim_output}
\title{Create a preformatted text output placeholder}
\usage{
verbatim_output(id)
}
\arguments{
\item{id}{character output ID}
}
\value{
A UI element
}
\description{
A pre element patched on textContent, so whitespace and line
breaks survive and the value is always displayed literally. Pair
with render_text() for console-style output such as str() dumps or
captured messages.
}
\examples{
verbatim_output("raw")
}
