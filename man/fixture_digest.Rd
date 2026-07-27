% tinyrox says don't edit this manually, but it can't stop you!
\name{fixture_digest}
\alias{fixture_digest}
\title{Digest of the fixture file as bytes}
\usage{
fixture_digest(path = fixture_json_path())
}
\arguments{
\item{path}{character file to hash; defaults to the installed copy}
}
\value{
character sha256, or NA when the file is absent
}
\description{
Byte-level rather than structural, because the consumers are in
different languages and canonical JSON serialization is not
something to litigate across two of them. The file is the artifact;
its sha256 is its identity.
}
\keyword{internal}
