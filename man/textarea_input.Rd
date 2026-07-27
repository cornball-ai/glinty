% tinyrox says don't edit this manually, but it can't stop you!
\name{textarea_input}
\alias{textarea_input}
\title{Create a multi-line text input}
\usage{
textarea_input(id, label = "", value = "", rows = 4L, placeholder = NULL,
               emit = "live")
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{character initial value}

\item{rows}{integer visible rows}

\item{placeholder}{character placeholder text}

\item{emit}{character "live" or "settle"}
}
\value{
A UI component
}
\description{
Create a multi-line text input
}
\examples{
textarea_input("notes", "Notes:", rows = 6L)
}
