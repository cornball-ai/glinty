% tinyrox says don't edit this manually, but it can't stop you!
\name{check_children}
\alias{check_children}
\title{Validate a list of children}
\usage{
check_children(children, fn)
}
\arguments{
\item{children}{list of candidate children}

\item{fn}{character calling function, for the error message}
}
\value{
the list, filtered and unnamed
}
\description{
NULLs are dropped so conditional children compose, but the index in
the error message is the caller's original one -- reporting a
post-filter index sends people looking at the wrong argument.
}
\details{
Reached through check_field() rather than called directly, so a
builder cannot forget it.

}
\keyword{internal}
