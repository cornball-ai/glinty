% tinyrox says don't edit this manually, but it can't stop you!
\name{page}
\alias{page}
\title{Create an HTML page}
\usage{
page(..., title = "glinty app", css = NULL, js = NULL, favicon = NULL,
     head = NULL)
}
\arguments{
\item{...}{child elements}

\item{title}{character page title}

\item{css}{character vector of stylesheet URLs, e.g.
"/static/styles.css"}

\item{js}{character vector of script URLs}

\item{favicon}{character URL of the tab icon}

\item{head}{a glinty_tag or raw character HTML appended to the
document head; the escape hatch for meta tags and anything else
glinty has no constructor for (trusted as-is, so do not pass
untrusted text)}
}
\value{
A UI tree (glinty_tag with title and head fields)
}
\description{
The top-level UI container. The title becomes the browser tab
title when the page is served.
}
\details{
App assets are referenced by URL, not by file path: serve them
from run_app()'s static_dir and point at them under /static/.
Stylesheets are linked after glinty's own, and scripts are loaded
after the JS client at the end of the body, so window.Glinty is
already defined when app code runs.

These arguments are browser-only; the native backend ignores them.

}
\examples{
page(h1("Hello"), title = "My app")
page(h1("Hello"), css = "/static/styles.css", favicon = "/static/logo.png")
}
