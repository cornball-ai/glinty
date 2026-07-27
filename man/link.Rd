% tinyrox says don't edit this manually, but it can't stop you!
\name{link}
\alias{link}
\title{Create a hyperlink}
\usage{
link(value, href, external = FALSE)
}
\arguments{
\item{value}{character link text}

\item{href}{character target URL}

\item{external}{logical open outside the app; a native client hands
this to the system browser}
}
\value{
A UI component
}
\description{
Create a hyperlink
}
\examples{
link("cornball.ai", "https://cornball.ai", external = TRUE)
}
