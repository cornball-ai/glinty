% tinyrox says don't edit this manually, but it can't stop you!
\name{static_mounts}
\alias{static_mounts}
\title{The app's static mounts}
\usage{
static_mounts(static_dir)
}
\arguments{
\item{static_dir}{NULL, a directory, or a named character vector
of directories}
}
\value{
a named character vector of mounts, the root mount named
  "", or NULL when nothing is served
}
\description{
`run_app(static_dir =)` takes one directory, served at /static/,
or a named character vector of directories each served under
/static/<name>/. The second form is for a page assembled from
parts that each bring an asset (a stylesheet, a font, an image):
with one directory the parts had to pick one of themselves, or
copy into one place at startup, or give up on all but one. One
entry may stay unnamed; it is the root mount, serving at /static/
whatever no named mount claims.
}
\details{
A single unnamed directory that does not exist is skipped: the
default "www" is a convenience, not a promise. A named directory
that does not exist is refused, because the author named it on
purpose and a silently unserved stylesheet is the failure this
exists to prevent.

}
\examples{
\dontrun{
run_app(app_obj, static_dir = c(fleet = "/srv/fleet/www",
                                notes = "/srv/notes/www"))
# then: page(css = "/static/fleet/style.css")
}
}
