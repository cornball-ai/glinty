% tinyrox says don't edit this manually, but it can't stop you!
\name{audio_output}
\alias{audio_output}
\title{Create an audio output slot}
\usage{
audio_output(id, controls = TRUE, autoplay = FALSE)
}
\arguments{
\item{id}{character output ID}

\item{controls}{logical show transport controls}

\item{autoplay}{logical begin playing on arrival}
}
\value{
A UI component
}
\description{
Create an audio output slot
}
\examples{
audio_output("player")
}
