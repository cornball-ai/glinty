% tinyrox says don't edit this manually, but it can't stop you!
\name{route_http}
\alias{route_http}
\title{Route a plain HTTP request}
\usage{
route_http(
  req,
  page_html,
  pkg_www,
  static_dir,
  started = as.numeric(Sys.time()),
  api = NULL,
  auth = NULL
)
}
\arguments{
\item{req}{parsed request}

\item{page_html}{character full page document}

\item{pkg_www}{character package asset dir (served at /glinty/)}

\item{static_dir}{character app asset dir (served at /static/),
or NULL}

\item{started}{numeric epoch seconds the server came up, for
/healthz uptime}

\item{api}{application router, or NULL (see run_app())}

\item{auth}{the configured verifier, for per-request principals}
}
\value{
raw HTTP response
}
\description{
Built-in routes first, then the mounted api (any method) for
whatever they did not claim, then 404. The built-ins winning is
what keeps an api from shadowing the page, the framework assets,
or the upload/download machinery.
}
\keyword{internal}
