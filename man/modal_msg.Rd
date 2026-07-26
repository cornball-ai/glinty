% tinyrox says don't edit this manually, but it can't stop you!
\name{modal_msg}
\alias{modal_msg}
\title{Create a modal open message}
\usage{
modal_msg(title, body, footer, easy_close)
}
\arguments{
\item{title}{character heading, or NULL}

\item{body}{list of unclassed tag trees}

\item{footer}{an unclassed tag tree, or NULL}

\item{easy_close}{logical dismiss on backdrop click or Escape}
}
\value{
character JSON string
}
\description{
Create a modal open message
}
\keyword{internal}
