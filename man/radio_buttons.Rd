% tinyrox says don't edit this manually, but it can't stop you!
\name{radio_buttons}
\alias{radio_buttons}
\title{Create a radio button group}
\usage{
radio_buttons(id, label = "", choices = character(0), selected = NULL)
}
\arguments{
\item{id}{character input ID (also the shared name of the group)}

\item{label}{character group label text}

\item{choices}{character vector of choices; names are display labels}

\item{selected}{character value checked initially (first choice by
default)}
}
\value{
A UI element
}
\description{
One input value shared by the group: the checked member's value.
}
\examples{
radio_buttons("mode", "Mode:", c(Fast = "fast", Careful = "careful"))
}
