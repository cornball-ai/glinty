% tinyrox says don't edit this manually, but it can't stop you!
\name{link}
\alias{link}
\title{Create a hyperlink}
\usage{
link(value = NULL, href, external = FALSE, ...)
}
\arguments{
\item{value}{character link text}

\item{href}{character target URL}

\item{external}{logical open outside the app; a native client hands
this to the system browser}

\item{...}{child components, for a link around something that is not
text (a logo, say). Give `value` or children, never both}
}
\value{
A UI component
}
\description{
Create a hyperlink
}
\examples{
link("cornball.ai", "https://cornball.ai", external = TRUE)
link(href = "https://cornball.ai", image("/static/logo.png"))
}
