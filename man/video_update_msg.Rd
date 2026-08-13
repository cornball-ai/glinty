% tinyrox says don't edit this manually, but it can't stop you!
\name{video_update_msg}
\alias{video_update_msg}
\title{Create a video playback message}
\usage{
video_update_msg(id, fields)
}
\arguments{
\item{id}{character output ID}

\item{fields}{named list of playback fields (current_time,
playing) with NULLs already dropped}
}
\value{
character JSON string
}
\description{
Playback state for a video_output, driven from the server: a seek
position, a play or a pause -- without replacing the element the
way a new output value would, which is what keeps the position and
the pipeline alive.
}
\keyword{internal}
