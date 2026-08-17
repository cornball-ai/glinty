% tinyrox says don't edit this manually, but it can't stop you!
\name{button}
\alias{button}
\title{Create a button}
\usage{
button(id, label, variant = "default", icon = NULL, value = NULL)
}
\arguments{
\item{id}{character button ID}

\item{label}{character button label}

\item{variant}{character "default", "primary", "secondary",
"danger" or "ghost"}

\item{icon}{character icon name shown before the label}

\item{value}{character carried on the event this button emits, so
one `observe_event()` can serve a whole list: the press says which
row. `input$id()` is then that value rather than a press count.
An id is valued everywhere or nowhere: give every button sharing
it a value, or none of them, since one observer cannot serve an
`input$id()` that is sometimes a value and sometimes a count}
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
button("history_view", "12:04", value = "entry_7")
}
