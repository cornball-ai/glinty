% tinyrox says don't edit this manually, but it can't stop you!
\name{render_image}
\alias{render_image}
\title{Render an image source}
\usage{
render_image(fn)
}
\arguments{
\item{fn}{zero-arg function returning the source string, or a list
with `src` and optionally `width` and `height` (logical pixels)}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
Sends an `image` output: `\{src, width?, height?\}`, dimensions in
logical pixels when given. `fn` may return the source string alone
or a list to add dimensions.
}
\details{
A source naming an existing file on the server is embedded as a
data URI -- a client cannot fetch server paths -- with the media
type read off the extension (an extension this does not know is an
error naming the fix, exactly as in [render_audio()]). Anything
else (`data:` URI, `/static/` path, http URL) already means
something to the client and passes through untouched.

[render_plot()] draws base graphics into a fresh raster;
this renders images that already exist (thumbnails, exported
frames, generated stills).

}
\examples{
\dontrun{
output$logo <- render_image(function() "/static/logo.png")
output$frame <- render_image(function() {
    list(src = exported_frame_path(), width = 320, height = 180)
})
}
}
