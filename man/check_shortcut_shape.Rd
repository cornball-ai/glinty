% tinyrox says don't edit this manually, but it can't stop you!
\name{check_shortcut_shape}
\alias{check_shortcut_shape}
\title{Require a well-formed shortcuts vector}
\usage{
check_shortcut_shape(x)
}
\arguments{
\item{x}{candidate shortcuts value}
}
\value{
the vector, invisibly validated
}
\description{
Shape only: every entry labelled, every path a non-empty string.
Existence, kind and root containment are show-time facts and are
filtered at show time instead.
}
\keyword{internal}
