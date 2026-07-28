% tinyrox says don't edit this manually, but it can't stop you!
\name{render_audio}
\alias{render_audio}
\title{Render an audio source}
\usage{
render_audio(fn)
}
\arguments{
\item{fn}{zero-arg function returning the source string}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
Sends an `audio` output: `\{src\}`, where src is a data URI or a
/static/ path.
}
\examples{
\dontrun{
output$player <- render_audio(function() "/static/chime.wav")
}
}
