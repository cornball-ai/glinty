% tinyrox says don't edit this manually, but it can't stop you!
\name{ui_output}
\alias{ui_output}
\title{Create a dynamic UI output placeholder}
\usage{
ui_output(id)
}
\arguments{
\item{id}{character output ID}
}
\value{
A UI element
}
\description{
The container for render_ui(): server-built tag trees replace its
contents at runtime, on both the browser and native frontends.
}
\examples{
ui_output("panel")
}
