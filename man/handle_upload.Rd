% tinyrox says don't edit this manually, but it can't stop you!
\name{handle_upload}
\alias{handle_upload}
\title{Handle a file upload POST}
\usage{
handle_upload(req)
}
\arguments{
\item{req}{parsed request with raw body}
}
\value{
raw HTTP response
}
\description{
POST /upload?ticket=<token> with a multipart body. The ticket was
minted over the WebSocket and binds the session and the input id,
so neither appears in the URL. File parts are written under a
per-session temp dir (removed when the session ends) and the input
becomes a data.frame with one row per file: name, size, type,
datapath. Text fields in the body become further columns, one
value each down every row (a chunked recording's index travels
this way). Dependent outputs update over the WebSocket on the next
tick.
}
\keyword{internal}
