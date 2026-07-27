% tinyrox says don't edit this manually, but it can't stop you!
\name{verbatim_output}
\alias{verbatim_output}
\title{Create a preformatted text output slot}
\usage{
verbatim_output(id)
}
\arguments{
\item{id}{character output ID}
}
\value{
A UI component
}
\description{
Whitespace and line breaks survive, and the value is always shown
literally. Pair with render_text() for console-style output such as
str() dumps or captured messages.
}
\examples{
verbatim_output("raw")
}
