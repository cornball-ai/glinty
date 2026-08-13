% tinyrox says don't edit this manually, but it can't stop you!
\name{video_output}
\alias{video_output}
\title{Create a video output slot}
\usage{
video_output(
  id,
  controls = TRUE,
  autoplay = FALSE,
  muted = FALSE,
  loop = FALSE
)
}
\arguments{
\item{id}{character output ID}

\item{controls}{logical show the player's transport controls}

\item{autoplay}{logical begin playing on arrival. Browsers block
autoplay with sound, so autoplay wants `muted = TRUE`}

\item{muted}{logical start muted}

\item{loop}{logical start over at the end}
}
\value{
A UI component
}
\description{
Pair with [render_video()]. The value's src wants to be a real URL
-- a `/static/` path the app serves -- rather than embedded bytes:
seeking works by byte-range requests against a URL, and a data URI
has no ranges to ask for.
}
\details{
The element fills its container's width on a dark letterbox and
keeps the video's own aspect. Playback can also be driven from the
server with [update_video()].

}
\examples{
video_output("preview")
}
