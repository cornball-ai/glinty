% tinyrox says don't edit this manually, but it can't stop you!
\name{text_input}
\alias{text_input}
\title{Create a text input}
\usage{
text_input(id, label = "", value = "", placeholder = NULL, emit = "live")
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{character initial value}

\item{placeholder}{character placeholder text}

\item{emit}{character "live" to report while typing, "settle" to
report when the field is committed}
}
\value{
A UI component
}
\description{
Create a text input
}
\examples{
text_input("name", "Name:")
}
