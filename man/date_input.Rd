% tinyrox says don't edit this manually, but it can't stop you!
\name{date_input}
\alias{date_input}
\title{Create a date input}
\usage{
date_input(id, label = "", value = NULL, min = NULL, max = NULL, emit = "settle")
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{character initial date, "YYYY-MM-DD"}

\item{emit}{character "live" or "settle"}

\item{min,max}{character selectable range}
}
\value{
A UI component
}
\description{
The value arrives server-side as a "YYYY-MM-DD" string; convert
with as.Date() at the point of use. No hidden coercion.
}
\examples{
date_input("start", "Start:", value = "2026-07-27")
}
