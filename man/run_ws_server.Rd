% tinyrox says don't edit this manually, but it can't stop you!
\name{run_ws_server}
\alias{run_ws_server}
\title{Run the HTTP + WebSocket server loop}
\usage{
run_ws_server(port, handlers, max_tick = 1)
}
\arguments{
\item{port}{integer TCP port}

\item{handlers}{list of on_request, on_open, on_message, on_close}

\item{max_tick}{numeric maximum select timeout in seconds}
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
queue before sleeping in socketSelect (timeout capped at max_tick
seconds so Ctrl-C stays responsive).
}
\keyword{internal}
