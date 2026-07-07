% tinyrox says don't edit this manually, but it can't stop you!
\name{button}
\alias{button}
\title{Create a button}
\usage{
button(id, label)
}
\arguments{
\item{id}{character button ID}

\item{label}{character button label}
}
\value{
A UI element
}
\description{
Clicks increment the input value (action-button semantics), so
observe_event(input$id, ...) fires once per click.
}
\examples{
button("go", "Run")
}
