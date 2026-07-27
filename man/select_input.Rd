% tinyrox says don't edit this manually, but it can't stop you!
\name{select_input}
\alias{select_input}
\title{Create a select dropdown}
\usage{
select_input(id, label = "", choices = character(0), selected = NULL,
             multiple = FALSE, emit = "settle")
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{choices}{character vector of choices; names are display
labels. A list of value/label pairs also works.}

\item{selected}{character value selected initially}

\item{multiple}{logical allow several selections}

\item{emit}{character "live" or "settle"}
}
\value{
A UI component
}
\description{
Create a select dropdown
}
\examples{
select_input("engine", "Engine:", c(Fast = "fast", Slow = "slow"))
}
