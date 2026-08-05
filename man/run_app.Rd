% tinyrox says don't edit this manually, but it can't stop you!
\name{run_app}
\alias{run_app}
\title{Run a glinty application}
\usage{
run_app(
  app_obj,
  port = NULL,
  auth = NULL,
  static_dir = "www",
  job_lanes = NULL,
  max_upload = 10485760L,
  check_secrets = TRUE,
  quiet = FALSE
)
}
\arguments{
\item{app_obj}{a glinty_app object}

\item{port}{integer HTTP port. NULL (the default) reads
GLINTY_PORT then PORT from the environment before falling back
to 8080, so a scheduler-allocated port needs no plumbing.}

\item{auth}{a function(token) verifying the opaque token a client
sends in hello: NULL from the function refuses the connection,
anything else becomes session$principal. NULL (the default)
accepts every connection with no principal. See jwt_auth() for
the JWT case.}

\item{static_dir}{character directory served under /static/
(default "www" in the working directory; skipped if absent)}

\item{job_lanes}{named list sizing the background-job lanes this
app offers, each list(concurrency =, queue =). A job picks its
lane; the app sizes it, for the same reason the ticket cap belongs
to the server. Lanes merge over the built-in
default = list(concurrency = 2, queue = 8), so naming a `gpu` lane
leaves `default` in place. Under a lane's queue depth a job waits;
past it the job is refused with a reason. See run_job().}

\item{max_upload}{integer largest accepted request body in bytes
(default 10 MB). Bodies are buffered whole in memory before
routing, so this is a memory ceiling as much as a policy one;
raise it deliberately for apps that take audio or video.
Oversized requests get a 413 without being read.}

\item{check_secrets}{logical refuse to start when the rendered page
contains the value of a secret-looking environment variable (see
env_secrets_in()). The usual cause is prefilling an input from
Sys.getenv(), which publishes the secret to anyone who can fetch
the page. Set FALSE only deliberately.}

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
\details{
Dropped connections detach their session rather than ending it:
observers and timers stay alive for
getOption("glinty.resume_grace", 60) seconds, and a client that
reconnects with the session id resumes where it left off (current
output state is replayed, no renderers re-run). Within that grace
window the session id acts as the resume credential -- acceptable
for the localhost/LAN tool scope, but treat it accordingly.

}
\examples{
\dontrun{
run_app(app_obj, port = 8080)
}
}
