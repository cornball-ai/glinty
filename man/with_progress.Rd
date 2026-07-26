% tinyrox says don't edit this manually, but it can't stop you!
\name{with_progress}
\alias{with_progress}
\title{Report progress during a long operation}
\usage{
with_progress(session, expr, message = "", detail = "", value = 0)
}
\arguments{
\item{session}{a glinty_session}

\item{expr}{the work to run}

\item{message}{character headline shown on the bar}

\item{detail}{character secondary line}

\item{value}{numeric starting fraction between 0 and 1}
}
\value{
the value of expr
}
\description{
Runs expr with a progress bar visible on the client, then removes
it. Inside expr, call inc_progress() or set_progress() to advance.
}
\details{
Each update is pushed to the client immediately rather than queued.
glinty runs one single-threaded event loop, so a blocking call
starves the normal drain and everything queued behind it would
arrive at once when the call returns -- a progress bar that jumps
straight from empty to gone. Updates only reach the browser between
blocking calls, so split long work into steps if you want the bar
to move.

Browser-only: the native backend ignores progress messages.

}
\examples{
\dontrun{
with_progress(session, message = "Transcribing...", {
    inc_progress(0.1, detail = "Preparing")
    wav <- ensure_wav(path)
    inc_progress(0.6, detail = "Running transcription")
    res <- stt.api::stt(wav)
    inc_progress(0.3, detail = "Done")
    res
})
}
}
