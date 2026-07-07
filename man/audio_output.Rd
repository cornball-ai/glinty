% tinyrox says don't edit this manually, but it can't stop you!
\name{audio_output}
\alias{audio_output}
\title{Create an audio output element}
\usage{
audio_output(id)
}
\arguments{
\item{id}{character output ID}
}
\value{
A UI element
}
\description{
The output renderer should set the src property to a data URI
or URL, e.g. with render_audio().
}
\examples{
audio_output("player")
}
