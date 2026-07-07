% tinyrox says don't edit this manually, but it can't stop you!
\name{full_page_html}
\alias{full_page_html}
\title{Wrap rendered HTML in a full page}
\usage{
full_page_html(body_html, title = "glinty app")
}
\arguments{
\item{body_html}{character HTML for the page body}

\item{title}{character page title}
}
\value{
character complete HTML document
}
\description{
Emits the document shell: the server-rendered UI inside
#glinty-root, the package stylesheet, and the JS client. Package
assets are served under /glinty/; app-local files under /static/.
}
\keyword{internal}
