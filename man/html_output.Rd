% tinyrox says don't edit this manually, but it can't stop you!
\name{html_output}
\alias{html_output}
\title{Create a raw HTML output slot}
\usage{
html_output(id)
}
\arguments{
\item{id}{character output ID}
}
\value{
A UI component
}
\description{
Browser-only, like tag(). The value is inserted as markup, so any
other frontend refuses it by name. Prefer ui_output() with
render_ui() for anything that must render on more than one client.
}
\examples{
html_output("details")
}
