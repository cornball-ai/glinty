% tinyrox says don't edit this manually, but it can't stop you!
\name{run_app}
\alias{run_app}
\title{Run a glinty application}
\usage{
run_app(
  app_obj,
  port = NULL,
  auth = NULL,
  origins = NULL,
  static_dir = "www",
  job_lanes = NULL,
  max_upload = 10485760L,
  check_secrets = TRUE,
  api = NULL,
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
the JWT case. A verifier declaring a second parameter is called
as auth(token, req), where req is the parsed WebSocket upgrade
request (method, path, query, headers with lower-cased names) --
so a credential the page cannot read, such as an HttpOnly
session cookie, is still visible to the verifier.}

\item{origins}{character vector of page origins allowed to open
the WebSocket, e.g. "https://app.example.com" (compared with
default ports stripped), or "*" to disable the check. NULL (the
default) allows pages served by this host only: the Origin
header must match the request's Host. Requests without an
Origin header -- native shells, CLI clients, tests -- are always
allowed. The check exists because browsers exempt WebSockets
from the same-origin policy, so without it any page a user
visits can open a socket to a running app and drive it. A
deployment behind a TLS proxy that forwards a nonstandard
Host:port should list its public origin here.}

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
Oversized requests get a 413 without being read. Applies to api
request bodies too.}

\item{check_secrets}{logical refuse to start when the rendered page
contains the value of a secret-looking environment variable (see
env_secrets_in()). The usual cause is prefilling an input from
Sys.getenv(), which publishes the secret to anyone who can fetch
the page. Set FALSE only deliberately.}

\item{api}{a function(method, path, body, query, principal)
mounting an application JSON API on the same origin, or NULL
(the default) for none. Consulted for any request the built-in
routes do not own, every method: return
`list(status =, body =)` for a JSON response (body is encoded
with auto-unboxing), `list(status =, json =)` for a
pre-serialized JSON string sent verbatim (a document that must
not be re-encoded, such as one another library wrote byte-stably;
content_type given, or application/json),
`list(status =, file =, content_type =)`
for a binary response, add a `headers` element for extras such as
Set-Cookie or Location (every element named, no CR/LF in values),
or return NULL to fall through
to glinty's own routing (a 404 for anything unclaimed). The
response shape is checked strictly: unknown fields, a
non-numeric status, or malformed headers answer the sanitized
500 rather than a degraded response. glinty
decodes the request without simplification, so a null field
stays distinct from an absent one and arrays of records keep
their shape: an object body arrives as a named list, an array as
an unnamed list, a scalar as itself (NULL when the body is
absent, unparseable, or not valid UTF-8). `query`
arrives as a named list of decoded strings. `principal` is
resolved per request by the
same `auth` verifier that gates WebSocket sessions, fed the
Authorization Bearer token (NULL when unauthenticated or auth is
not configured -- the api function decides what an anonymous
caller may do, since public routes like a ping are its
business). Errors inside the function, or while encoding its
answer, answer 500 with a generic
body; the condition message goes to the server log, not the
wire.}

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
