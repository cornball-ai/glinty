% tinyrox says don't edit this manually, but it can't stop you!
\name{computed_measure}
\alias{computed_measure}
\title{Measure one page in a headless browser}
\usage{
computed_measure(html, chrome, dir, tag)
}
\arguments{
\item{html}{character document}

\item{chrome}{character browser binary}

\item{dir}{character working directory for the run}

\item{tag}{character file name stem}
}
\value{
named list: "base|state|property" -> list(distinct, values)
}
\description{
Measure one page in a headless browser
}
\keyword{internal}
