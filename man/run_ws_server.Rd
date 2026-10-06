% tinyrox says don't edit this manually, but it can't stop you!
\name{run_ws_server}
\alias{run_ws_server}
\title{Run the HTTP + WebSocket server loop}
\usage{
run_ws_server(port, handlers, max_tick = 1, host = NULL, tls_cert = NULL)
}
\arguments{
\item{port}{integer TCP port}

\item{handlers}{list of on_request, on_open, on_message, on_close}

\item{max_tick}{numeric maximum wait timeout in seconds}

\item{host}{character bind address, or NULL for every interface}

\item{tls_cert}{character PEM path, or NULL for plain http}
}
\value{
invisible(NULL); runs until interrupt
}
\description{
Blocks until interrupted. Handlers connect the transport to the
app layer: on_request(req) returns a raw HTTP response (or NULL
for 404), on_open(session_id) / on_message(session_id, txt) /
on_close(session_id) manage sessions. Each loop tick fires due
timers, flushes reactions, and drains every session's outgoing
queue before sleeping in the transport's wait (timeout capped at
max_tick seconds so Ctrl-C stays responsive).
}
\keyword{internal}
