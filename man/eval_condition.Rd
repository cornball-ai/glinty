% tinyrox says don't edit this manually, but it can't stop you!
\name{eval_condition}
\alias{eval_condition}
\title{Evaluate a condition against a session's inputs}
\usage{
eval_condition(cond, session)
}
\arguments{
\item{cond}{a decoded condition list (from condition_json)}

\item{session}{a glinty_session}
}
\value{
logical
}
\description{
The R-side twin of the client's interpreter, used by the native
backend, which has no JavaScript to run the browser one. The two
must agree, so the matching rule is the same: logicals compare by
truthiness, everything else by string, and an input that was never
set matches nothing.
}
\keyword{internal}
