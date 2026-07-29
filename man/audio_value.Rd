% tinyrox says don't edit this manually, but it can't stop you!
\name{audio_value}
\alias{audio_value}
\title{Check an audio value into the shape the protocol states}
\usage{
audio_value(v)
}
\arguments{
\item{v}{list with `src` and optionally `mime` and `duration`}
}
\value{
list(src, mime, duration?)
}
\description{
Every field is a scalar, so every check here is the same check: one
value, present, and of the kind the field means. as.character() on
a two-element vector is a JSON array on a wire that promised a
string, and the client that meets it has no way to say what went
wrong -- the app does, here, where the mistake was made.
}
\keyword{internal}
