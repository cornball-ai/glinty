% tinyrox says don't edit this manually, but it can't stop you!
\name{wire_transcripts}
\alias{wire_transcripts}
\title{Wire transcripts every client must handle}
\usage{
wire_transcripts()
}
\value{
list of transcripts
}
\description{
Each entry is list(name, notes, frames), where frames are
list(dir, message) and dir is "in" (client to server) or "out"
(server to client).
}
\keyword{internal}
