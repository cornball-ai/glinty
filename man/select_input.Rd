% tinyrox says don't edit this manually, but it can't stop you!
\name{select_input}
\alias{select_input}
\title{Create a select dropdown}
\usage{
select_input(id, label = "", choices = character(0), selected = NULL)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{choices}{character vector of choices; names are display labels}

\item{selected}{character value to select initially}
}
\value{
A UI element
}
\description{
Create a select dropdown
}
\examples{
select_input("engine", "Engine:", c(Fast = "fast", Slow = "slow"))
}
