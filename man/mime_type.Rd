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
webm is registered as video/webm for the container, but glinty
produces audio-only webm and an <audio> element wants audio/webm.
It stays audio here for that reason: a served .webm is one glinty
wrote. mp4/m4v/mov carry no such history and map to video, which is
what a <video> element needs to play a file at all.
}
\keyword{internal}
