% tinyrox says don't edit this manually, but it can't stop you!
\name{button}
\alias{button}
\title{Create a button}
\usage{
button(id, label, variant = "default", icon = NULL)
}
\arguments{
\item{id}{character button ID}

\item{label}{character button label}

\item{variant}{character "default", "primary", "secondary",
"danger" or "ghost"}

\item{icon}{character icon name shown before the label}
}
\value{
A UI component
}
\description{
A button emits an event rather than an input: there is no value the
server keeps. observe_event(input$id, ...) fires once per press.
}
\examples{
button("go", "Run", variant = "primary")
}
