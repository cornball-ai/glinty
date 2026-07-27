% tinyrox says don't edit this manually, but it can't stop you!
\name{ui_output}
\alias{ui_output}
\title{Create a dynamic UI slot}
\usage{
ui_output(id)
}
\arguments{
\item{id}{character output ID}
}
\value{
A UI component
}
\description{
The container for render_ui(): server-built component trees replace
its contents at runtime. Inputs that first appear inside dynamic UI
start as NULL server-side until the user touches them.
}
\examples{
ui_output("panel")
}
