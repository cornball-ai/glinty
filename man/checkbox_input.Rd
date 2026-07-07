% tinyrox says don't edit this manually, but it can't stop you!
\name{checkbox_input}
\alias{checkbox_input}
\title{Create a checkbox input}
\usage{
checkbox_input(id, label = "", value = FALSE)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{logical initial checked state}
}
\value{
A UI element
}
\description{
Create a checkbox input
}
\examples{
checkbox_input("save", "Save results", value = TRUE)
}
