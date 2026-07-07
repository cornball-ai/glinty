% tinyrox says don't edit this manually, but it can't stop you!
\name{run_app}
\alias{run_app}
\title{Run a glinty application}
\usage{
run_app(app_obj, port = 8080L, static_dir = "www", quiet = FALSE)
}
\arguments{
\item{app_obj}{a glinty_app object}

\item{port}{integer HTTP port (default 8080)}

\item{static_dir}{character directory served under /static/
(default "www" in the working directory; skipped if absent)}

\item{quiet}{logical suppress the startup message}
}
\value{
invisible(NULL); runs until interrupt
}
\description{
Serves the app over HTTP with a WebSocket per browser tab, all on
base R sockets in a single-threaded event loop. Blocks until
interrupted (Ctrl-C). Note base R's serverSocket() listens on all
interfaces; treat the port as reachable from the local network.
}
\examples{
\dontrun{
run_app(app_obj, port = 8080)
}
}
