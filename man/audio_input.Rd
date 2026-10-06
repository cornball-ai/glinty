% tinyrox says don't edit this manually, but it can't stop you!
\name{audio_input}
\alias{audio_input}
\title{Create a microphone input}
\usage{
audio_input(id, label = "Record", chunk = NULL, mime = NULL)
}
\arguments{
\item{id}{character input ID}

\item{label}{character the button's text while idle}

\item{chunk}{NULL, or seconds between chunk uploads while recording}

\item{mime}{NULL, or the preferred recording type, such as
\code{"audio/webm;codecs=opus"}; the client falls back to what it
supports}
}
\value{
A UI component
}
\description{
A button that records from the device microphone. The take arrives
the way a \code{\link{file_input}}'s files do, over HTTP through a
transfer ticket, so the value has the same shape: a data.frame with
one row, \code{name}, \code{size}, \code{type}, \code{datapath}.
Pressing the button starts recording and relabels it "Stop";
pressing again stops and uploads.
}
\details{
Two companion inputs ride beside it, under the component's id.
\code{input$<id>_state} is \code{"idle"}, \code{"recording"},
\code{"denied"} (microphone permission refused),
\code{"unsupported"} (no recorder in this client) or
\code{"insecure"} (the page is not https or localhost, which
browsers require before they open a microphone). With \code{chunk}
set, \code{input$<id>_chunk} receives each chunk as it closes, a
one-row data.frame with an \code{index} column, so a live
transcription can read the recording while it is still going; each
chunk decodes on its own. The whole take still arrives on stop.

A client that cannot record declares no \code{record} feature in
its hello and refuses the component by name.

}
\examples{
audio_input("take", "Record")
audio_input("live", chunk = 5)
}
