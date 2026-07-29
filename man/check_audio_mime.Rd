% tinyrox says don't edit this manually, but it can't stop you!
\name{check_audio_mime}
\alias{check_audio_mime}
\title{Refuse a media type that is not one}
\usage{
check_audio_mime(mime)
}
\arguments{
\item{mime}{character lowercase media type}
}
\value{
mime, invisibly refused by stop() when it is not audio
}
\description{
The field names an audio source, so a type outside the audio family
is a mistake worth catching where it was made -- a native client
would hand it to a player that cannot open it and report something
about the file instead.
}
\keyword{internal}
