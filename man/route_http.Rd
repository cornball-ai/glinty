% tinyrox says don't edit this manually, but it can't stop you!
\name{route_http}
\alias{route_http}
\title{Route a plain HTTP request}
\usage{
route_http(req, page_html, pkg_www, static_dir)
}
\arguments{
\item{req}{parsed request}

\item{page_html}{character full page document}

\item{pkg_www}{character package asset dir (served at /glinty/)}

\item{static_dir}{character app asset dir (served at /static/),
or NULL}
}
\value{
raw HTTP response
}
\description{
Route a plain HTTP request
}
\keyword{internal}
