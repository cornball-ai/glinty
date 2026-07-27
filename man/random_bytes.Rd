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
openssl's CSPRNG when the package is present, the kernel's
/dev/urandom otherwise -- which covers every platform glinty
serves from. A platform with neither gets an error naming the fix
rather than silently weaker credentials.
}
\keyword{internal}
