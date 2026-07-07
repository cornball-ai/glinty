% tinyrox says don't edit this manually, but it can't stop you!
\name{date_input}
\alias{date_input}
\title{Create a date input}
\usage{
date_input(id, label = "", value = NULL, min = NULL, max = NULL)
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{character initial date, "YYYY-MM-DD" (optional)}

\item{min}{character earliest selectable date (optional)}

\item{max}{character latest selectable date (optional)}
}
\value{
A UI element
}
\description{
The input value arrives server-side as a "YYYY-MM-DD" string;
convert with as.Date() at the point of use. No hidden coercion.
}
\examples{
date_input("start", "Start:", value = "2026-07-07")
}
