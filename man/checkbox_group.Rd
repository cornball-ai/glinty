% tinyrox says don't edit this manually, but it can't stop you!
\name{checkbox_group}
\alias{checkbox_group}
\title{Create a checkbox group input}
\usage{
checkbox_group(
  id,
  label = "",
  choices = character(0),
  selected = NULL,
  emit = "settle"
)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{choices}{choices in any of the usual shapes}

\item{selected}{character values checked at start; NULL for none}

\item{emit}{character "settle" (default) or "live"}
}
\value{
A UI component
}
\description{
One id, many boxes: the value is the array of checked members'
values, an array at every length -- `["a"]`, never `"a"` -- the
same rule as a multiple select. Order follows the choices, not
the clicks. Unlike [radio_buttons()], nothing is selected unless
`selected` says so: an empty selection is a real state here.
}
\examples{
checkbox_group("show_vars", "Columns:",
    choices = c("carat", "cut", "color"),
    selected = c("carat", "cut"))
}
