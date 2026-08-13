% tinyrox says don't edit this manually, but it can't stop you!
\name{video_value}
\alias{video_value}
\title{Check a video value into the shape the protocol states}
\usage{
video_value(v)
}
\arguments{
\item{v}{list with `src` and optionally `mime`, `poster`,
`duration`}
}
\value{
list(src, mime, poster?, duration?)
}
\description{
audio_value()'s discipline, plus two of its own: a server file
path is refused rather than embedded (see [render_video()]), and a
poster naming a server file becomes a data URI here, where the
bytes are reachable.
}
\keyword{internal}
