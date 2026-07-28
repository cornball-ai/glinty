% tinyrox says don't edit this manually, but it can't stop you!
\name{random_bytes}
\alias{random_bytes}
\title{Cryptographically random bytes}
\usage{
random_bytes(n)
}
\arguments{
\item{n}{integer byte count}
}
\value{
raw vector of length n
}
\description{
One source, every platform: openssl's CSPRNG. This is why openssl
is an Import rather than a Suggests -- session ids and tickets are
bearer credentials on every platform glinty runs on, base R has no
CSPRNG, and /dev/urandom is not a cross-platform answer (a Windows
server would have silently fallen through to an error, or worse to
something weaker). A dependency that is always needed belongs in
Imports.
}
\keyword{internal}
