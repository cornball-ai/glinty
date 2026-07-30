% tinyrox says don't edit this manually, but it can't stop you!
\name{image_mime}
\alias{image_mime}
\title{The media type of an image file}
\usage{
image_mime(src)
}
\arguments{
\item{src}{character file path}
}
\value{
character media type
}
\description{
Read off the extension, which is stated, not guessed. An unknown
extension is an error naming the fix rather than a type invented to
fill the data URI.
}
\keyword{internal}
