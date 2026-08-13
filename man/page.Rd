% tinyrox says don't edit this manually, but it can't stop you!
\name{page}
\alias{page}
\title{Create a page}
\usage{
page(
  ...,
  title = "glinty app",
  width = "content",
  css = NULL,
  js = NULL,
  favicon = NULL,
  head = NULL
)
}
\arguments{
\item{...}{child components}

\item{title}{character page title}

\item{width}{character "content" for the centred reading column,
"full" for the whole viewport. Forms and documents read best in a
column; a workspace with side-by-side panels wants everything}

\item{css}{character vector of stylesheet URLs, e.g.
"/static/styles.css"}

\item{js}{character vector of script URLs}

\item{favicon}{character URL of the tab icon}

\item{head}{a raw character HTML string appended to the document
head; the escape hatch for meta tags. Trusted as-is.}
}
\value{
A UI component
}
\description{
The top-level container. The title becomes the browser tab title
when served, and the app name a native client shows.
}
\details{
The asset arguments are browser-only and travel outside the
component tree, since a Flutter client has no use for a stylesheet.

}
\examples{
page(heading("Hello"), title = "My app")
page(row(panel(txt("left")), panel(txt("right"))), width = "full")
}
