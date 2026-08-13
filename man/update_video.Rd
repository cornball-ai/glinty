% tinyrox says don't edit this manually, but it can't stop you!
\name{update_video}
\alias{update_video}
\title{Drive a video output's playback from the server}
\usage{
update_video(session, id, current_time = NULL, playing = NULL)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character video output ID}

\item{current_time}{numeric seek position in seconds}

\item{playing}{logical TRUE plays, FALSE pauses}
}
\value{
invisible(NULL)
}
\description{
Seeks and plays/pauses the client's player without touching its
source -- a new output value swaps the video, this moves inside
it. The shape that wants it is an external playhead (a timeline, a
transport slider) kept in sync with a preview player.
}
\details{
Both fields are optional and NULL leaves that half of the state
alone: `update_video(session, id, playing = FALSE)` pauses without
seeking, `update_video(session, id, current_time = 0)` rewinds
without deciding whether to play.

A play may still be refused by the client -- browsers block
unmuted playback before the user has interacted with the page --
and a refusal is the client's to report, not a round trip this
waits on.

}
\examples{
\dontrun{
update_video(session, "preview", current_time = 3.5, playing = TRUE)
}
}
