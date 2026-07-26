% tinyrox says don't edit this manually, but it can't stop you!
\name{page_head}
\alias{page_head}
\title{Build a page head spec}
\usage{
page_head(css = NULL, js = NULL, favicon = NULL, extra = NULL)
}
\arguments{
\item{css}{character vector of stylesheet URLs}

\item{js}{character vector of script URLs}

\item{favicon}{character icon URL}

\item{extra}{a glinty_tag or raw character HTML appended to head}
}
\value{
a list, or NULL when nothing was supplied
}
\description{
Normalizes page()'s asset arguments into the list carried on the
UI tree and consumed by full_page_html().
}
\keyword{internal}
