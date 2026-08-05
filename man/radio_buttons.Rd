% tinyrox says don't edit this manually, but it can't stop you!
\name{radio_buttons}
\alias{radio_buttons}
\title{Create a radio button group}
\usage{
radio_buttons(
  id,
  label = "",
  choices = character(0),
  selected = NULL,
  emit = "settle"
)
}
\arguments{
\item{id}{character input ID}

\item{label}{character group label}

\item{choices}{character vector of choices; names are display labels}

\item{selected}{character value selected initially}

\item{emit}{character "live" or "settle"}
}
\value{
A UI component
}
\description{
One input value shared by the group: the selected member's value.
}
\examples{
radio_buttons("mode", "Mode:", c(Fast = "fast", Careful = "careful"))
}
