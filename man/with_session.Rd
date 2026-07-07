% tinyrox says don't edit this manually, but it can't stop you!
\name{with_session}
\alias{with_session}
\title{Evaluate an expression with a session as the current domain}
\usage{
with_session(session, expr)
}
\arguments{
\item{session}{a glinty_session}

\item{expr}{expression to evaluate}
}
\value{
the result of expr
}
\description{
Observers created during evaluation are tagged with this session,
so session_end() can destroy them.
}
\keyword{internal}
