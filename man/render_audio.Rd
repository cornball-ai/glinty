% tinyrox says don't edit this manually, but it can't stop you!
\name{render_audio}
\alias{render_audio}
\title{Render an audio source}
\usage{
render_audio(fn)
}
\arguments{
\item{fn}{zero-arg function returning the source string, or a list
with `src` and optionally `mime` and `duration` (seconds)}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
Sends an `audio` output: `\{src, mime, duration?\}`, where src is a
data URI or a /static/ path.
}
\details{
`mime` is not optional. A browser sniffs the bytes and does not
need it, which is why it went missing for so long; a native client
has to hand the source to a platform player that asks what it is.
So fn may return the src alone and let this read the type out of
the data URI or off the file extension -- neither is a guess, both
are stated in the string -- or return a list to say outright:

\preformatted{
render_audio(function() list(src = uri, mime = "audio/wav",
duration = 12.5))
}

An extension this does not know is an error naming the fix rather
than a value invented to fill the field.

}
\examples{
\dontrun{
output$player <- render_audio(function() "/static/chime.wav")
}
}
