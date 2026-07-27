% tinyrox says don't edit this manually, but it can't stop you!
\name{tag}
\alias{tag}
\title{Emit raw HTML}
\usage{
tag(html)
}
\arguments{
\item{html}{character raw HTML}
}
\value{
A UI component
}
\description{
The browser-only escape hatch, for markup with no component
equivalent. The string is trusted as-is and inserted unescaped, so
never pass untrusted text through it.
}
\details{
Any frontend other than the browser refuses it by name and draws a
visible placeholder, since arbitrary markup cannot be translated
into a widget tree. Content that has to appear everywhere belongs
in the component set instead.

}
\examples{
tag("<details><summary>More</summary>body</details>")
}
