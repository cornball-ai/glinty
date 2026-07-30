% tinyrox says don't edit this manually, but it can't stop you!
\name{image_value}
\alias{image_value}
\title{Check an image value into the shape the protocol states}
\usage{
image_value(v)
}
\arguments{
\item{v}{list with `src` and optionally `width` and `height`}
}
\value{
list(src, width?, height?)
}
\description{
Same discipline as audio_value(): every field is one value of the
kind the field means, and a server file becomes a data URI here,
where the bytes are reachable.
}
\keyword{internal}
