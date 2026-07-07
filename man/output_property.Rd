% tinyrox says don't edit this manually, but it can't stop you!
\name{output_property}
\alias{output_property}
\title{Set the DOM property for an output}
\usage{
output_property(output, id, property)
}
\arguments{
\item{output}{a glinty_output proxy}

\item{id}{character output ID}

\item{property}{character DOM property name}
}
\value{
invisible(NULL)
}
\description{
By default, output observers update textContent. Call this before
assigning the output function to use a different property (e.g.
"src" for audio, "innerHTML" for HTML output).
}
\examples{
\dontrun{
output_property(output, "player", "src")
output$player <- function() audio_data_uri()
}
}
