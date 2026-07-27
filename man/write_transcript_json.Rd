% tinyrox says don't edit this manually, but it can't stop you!
\name{write_transcript_json}
\alias{write_transcript_json}
\title{Regenerate the checked-in transcript JSON}
\usage{
write_transcript_json(path = "inst/fixtures/transcripts.json")
}
\arguments{
\item{path}{character destination}
}
\value{
the path, invisibly
}
\description{
Run after changing wire_transcripts(). A test compares the file
against transcript_json() and fails on drift.
}
\keyword{internal}
