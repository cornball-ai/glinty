% tinyrox says don't edit this manually, but it can't stop you!
\name{computed_probe_html}
\alias{computed_probe_html}
\title{Build the page the browser measures}
\usage{
computed_probe_html(app_css, glinty_css, families, props)
}
\arguments{
\item{app_css}{character app stylesheet text, or NULL for the
baseline page}

\item{glinty_css}{character glinty stylesheet text}

\item{families}{list from computed_probe_families()}

\item{props}{named list of properties to read, per base class}
}
\value{
character HTML document
}
\description{
Build the page the browser measures
}
\keyword{internal}
