% tinyrox says don't edit this manually, but it can't stop you!
\name{build_native_ops}
\alias{build_native_ops}
\title{Build flitR ops for a glinty UI tree}
\usage{
build_native_ops(ui, session, values)
}
\arguments{
\item{ui}{a glinty_tag tree from page()}

\item{session}{the native glinty_session}

\item{values}{env of output id -> latest client-ready value}
}
\value{
list of flitR ops/widgets (nested; scene() flattens)
}
\description{
Build flitR ops for a glinty UI tree
}
\keyword{internal}
