% tinyrox says don't edit this manually, but it can't stop you!
\name{tag}
\alias{tag}
\title{Emit trusted raw HTML}
\usage{
tag(html)
}
\arguments{
\item{html}{character trusted raw HTML}
}
\value{
A UI component
}
\description{
The browser-only escape hatch, for markup with no component
equivalent.
}
\details{
**The string is inserted into the page unescaped.** It is trusted
HTML, not text: markup in it is markup, and a `<script>` in it
runs. So the argument must be a literal you wrote, or built from
parts you control. Never interpolate a user-supplied string, a
request parameter, a filename, a database field or a model
response into it. That is cross-site scripting, and glinty does
nothing to stop it here by design -- escaping the string would
defeat the only purpose the function has.

For text of any provenance, use \code{\link{txt}()}, which travels
as a value and is escaped by whichever frontend renders it. If you
genuinely need markup around untrusted text, run the text through
\code{\link{html_escape}()} before pasting it in.

Any frontend other than the browser refuses it by name and draws a
visible placeholder, since arbitrary markup cannot be translated
into a widget tree. Content that has to appear everywhere belongs
in the component set instead.

}
\examples{
tag("<details><summary>More</summary>body</details>")

# untrusted text needs escaping first
name <- "<script>alert(1)</script>"
tag(paste0("<figcaption>", html_escape(name), "</figcaption>"))
}
\seealso{
\code{\link{txt}} for untrusted text,
  \code{\link{html_escape}} to escape it
}
