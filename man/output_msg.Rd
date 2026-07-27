% tinyrox says don't edit this manually, but it can't stop you!
\name{output_msg}
\alias{output_msg}
\title{Create an output message}
\usage{
output_msg(id, kind, value)
}
\arguments{
\item{id}{character output ID}

\item{kind}{character one of text, html, table, image, audio, ui}

\item{value}{the renderer's value}
}
\value{
character JSON string
}
\description{
An output's current value, typed by what the renderer produced --
not by the DOM property a browser would patch. How a value is
displayed belongs to the receiving component; `kind` only says
what the value is.
}
\keyword{internal}
