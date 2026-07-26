% tinyrox says don't edit this manually, but it can't stop you!
\name{check_page_secrets}
\alias{check_page_secrets}
\title{Refuse to serve a page containing a secret}
\usage{
check_page_secrets(page_html, strict = TRUE)
}
\arguments{
\item{page_html}{character the rendered page}

\item{strict}{logical stop (TRUE) or warn (FALSE)}
}
\value{
invisible character vector of offending variable names
}
\description{
The failure this exists to stop: prefilling an input from
Sys.getenv(), which renders the secret into the page source as a
plain attribute. type="password" masks the screen, not the HTML, so
the value is readable by anyone who can fetch the page -- and base
R's serverSocket() listens on all interfaces.
}
\details{
Stops rather than warns, because a warning at startup scrolls past
and the app keeps serving the secret.

}
\keyword{internal}
