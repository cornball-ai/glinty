% tinyrox says don't edit this manually, but it can't stop you!
\name{video_mime}
\alias{video_mime}
\title{The media type of a video source}
\usage{
video_mime(src)
}
\arguments{
\item{src}{character data URI or path}
}
\value{
character media type
}
\description{
audio_mime()'s rule: a data URI declares its own type, a path's
extension states one, and neither is a guess. Note the value's
webm is video/webm; serve_static() names the *file* audio/webm,
which is a different question (see mime_type()).
}
\keyword{internal}
