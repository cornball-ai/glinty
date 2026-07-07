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
POST /upload?session=<sid>&id=<input_id> with a multipart body.
File parts are written under a per-session temp dir (removed when
the session ends) and the input becomes a data.frame with one row
per file: name, size, type, datapath. Dependent outputs update
over the WebSocket on the next tick.
}
\keyword{internal}
