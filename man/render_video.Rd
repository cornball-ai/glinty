% tinyrox says don't edit this manually, but it can't stop you!
\name{render_video}
\alias{render_video}
\title{Render a video source}
\usage{
render_video(fn)
}
\arguments{
\item{fn}{zero-arg function returning the source string, or a list
with `src` and optionally `mime`, `poster` and `duration`
(seconds)}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
Sends a `video` output: `\{src, mime, poster?, duration?\}`. The
media-type discipline is [render_audio()]'s: fn may return the src
alone and let this read the type off the extension or out of a
data URI, or return a list to say outright -- and a type it cannot
read is an error naming the fix.
}
\details{
The src wants to be a URL the client can fetch -- a `/static/`
path the app serves -- rather than embedded bytes. Seeking works
by byte-range requests against a URL, which glinty's static server
answers; a data URI has no ranges to ask for, so it plays but
cannot scrub. A server file path is therefore refused rather than
embedded: video is the one media size where a data URI on every
reactive tick stops being a convenience. Browsers cache by URL, so
a re-rendered cut wants a new file name, not the old one
rewritten.

`poster` is the frame shown before play. An existing server file
is embedded as a data URI (it is one image, [render_image()]'s
deal); a URL passes through.

}
\examples{
\dontrun{
output$preview <- render_video(function() "/static/cut.mp4")
}
}
