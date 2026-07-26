% tinyrox says don't edit this manually, but it can't stop you!
\name{download_handler}
\alias{download_handler}
\title{Register a download for this session}
\usage{
download_handler(session, id, filename, content)
}
\arguments{
\item{session}{a glinty_session}

\item{id}{character download ID, matching a download_button()}

\item{filename}{character name offered to the browser, or a
zero-argument function returning one}

\item{content}{function(file) that writes the payload to the path
it is given}
}
\value{
invisible(NULL)
}
\description{
Wires a download_button() to the bytes it should deliver. The
handler is not reactive and not an output: it runs when the browser
asks for the file, over a plain GET rather than the WebSocket.
}
\details{
filename and content are called at request time, so they see
current reactive state. Read any inputs they need through
isolate(), since there is no reactive context on an HTTP request.

The session id in the URL is the credential, the same as for
file_input() uploads and resume. Fine for the localhost and LAN
tool scope glinty targets; treat it accordingly.

}
\examples{
\dontrun{
download_handler(
    session, "download_audio",
    filename = function() paste0("speech-", Sys.Date(), ".wav"),
    content = function(file) file.copy(isolate(audio_path()), file)
)
}
}
