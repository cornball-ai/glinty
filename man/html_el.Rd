% tinyrox says don't edit this manually, but it can't stop you!
\name{html_el}
\alias{html_el}
\title{Build an HTML element}
\usage{
html_el(tag_name, attrs = list(), inner = "", void = FALSE)
}
\arguments{
\item{tag_name}{character element name}

\item{attrs}{named list of attributes; NULLs are dropped}

\item{inner}{character inner HTML, already escaped or built}

\item{void}{logical self-closing element}
}
\value{
character HTML
}
\description{
Build an HTML element
}
\keyword{internal}
