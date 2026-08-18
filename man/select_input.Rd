% tinyrox says don't edit this manually, but it can't stop you!
\name{select_input}
\alias{select_input}
\title{Create a select dropdown}
\usage{
select_input(
  id,
  label = "",
  choices = character(0),
  selected = NULL,
  multiple = FALSE,
  search = FALSE,
  emit = "settle"
)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{choices}{character vector of choices; names are display
labels. A list of value/label pairs also works.}

\item{selected}{character value selected initially}

\item{multiple}{logical allow several selections}

\item{search}{logical filter-as-you-type over the choices
(single-select only)}

\item{emit}{character "live" or "settle"}
}
\value{
A UI component
}
\description{
With `search = TRUE` the control is a combobox: typing filters the
same closed choice list, and only picking a real choice reports a
value -- the typed text is a view, never a value, so the input's
domain stays exactly the declared choices. Single-select only;
a multiple select already filters by scrolling and refuses the
flag. Long lists (dozens up) are where it earns the extra control.
}
\examples{
select_input("engine", "Engine:", c(Fast = "fast", Slow = "slow"))
select_input("state", "State:", datasets::state.name, search = TRUE)
}
