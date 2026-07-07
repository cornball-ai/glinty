% tinyrox says don't edit this manually, but it can't stop you!
\name{html_output}
\alias{html_output}
\title{Create an HTML output placeholder}
\usage{
html_output(id)
}
\arguments{
\item{id}{character output ID}
}
\value{
A UI element
}
\description{
Unlike text_output, the output value is set as innerHTML rather
than textContent. Use with render_html() for markup from R.
}
\examples{
html_output("details")
}
