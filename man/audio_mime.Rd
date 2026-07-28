% tinyrox says don't edit this manually, but it can't stop you!
\name{audio_mime}
\alias{audio_mime}
\title{The media type of an audio source}
\usage{
audio_mime(src)
}
\arguments{
\item{src}{character data URI or path}
}
\value{
character media type
}
\description{
Read out of the source rather than guessed at: a data URI declares
its own type, and a path's extension is the only thing anyone has
to go on. Neither is inference -- both are written in the string.
}
\keyword{internal}
