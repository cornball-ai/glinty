% tinyrox says don't edit this manually, but it can't stop you!
\name{checkbox_input}
\alias{checkbox_input}
\title{Create a checkbox}
\usage{
checkbox_input(id, label = "", value = FALSE, emit = "settle")
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{logical initial state}

\item{emit}{character "live" or "settle"}
}
\value{
A UI component
}
\description{
Create a checkbox
}
\examples{
checkbox_input("save", "Save results", value = TRUE)
}
