% tinyrox says don't edit this manually, but it can't stop you!
\name{full_page_html}
\alias{full_page_html}
\title{Wrap rendered HTML in a full page}
\usage{
full_page_html(body_html, title = "glinty app", head = NULL, ui_revision = NULL)
}
\arguments{
\item{body_html}{character HTML for the page body}

\item{title}{character page title}

\item{head}{a page head spec (see page_head()), or NULL}

\item{ui_revision}{character revision of the tree body_html was
rendered from, embedded as a meta tag so the client can tell
whether this markup describes the tree welcome sends it; NULL
omits the tag (a client without one rebuilds from welcome)}
}
\value{
character complete HTML document
}
\description{
Emits the document shell: the server-rendered UI inside
#glinty-root, the package stylesheet, and the JS client. Package
assets are served under /glinty/; app-local files under /static/.
}
\details{
App stylesheets land after glinty.css so they win on equal
specificity. App scripts land after glinty.js at the end of the
body, so window.Glinty already exists when they run.

}
\keyword{internal}
