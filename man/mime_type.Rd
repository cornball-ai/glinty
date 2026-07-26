% tinyrox says don't edit this manually, but it can't stop you!
\name{mime_type}
\alias{mime_type}
\title{Map a file extension to a MIME type}
\usage{
mime_type(ext)
}
\arguments{
\item{ext}{character file extension, with or without case}
}
\value{
character MIME type, falling back to
  application/octet-stream
}
\description{
webm is registered as video/webm for the container, but glinty's
only media output is audio, and audio-only webm in an <audio>
element wants audio/webm.
}
\keyword{internal}
