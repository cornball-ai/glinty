% tinyrox says don't edit this manually, but it can't stop you!
\name{seed_session_inputs}
\alias{seed_session_inputs}
\title{Seed a session's inputs from its component tree}
\usage{
seed_session_inputs(session, ui)
}
\arguments{
\item{session}{a glinty_session}

\item{ui}{a component tree}
}
\value{
invisible(NULL)
}
\description{
Runs before the server function, so every input the tree declares
reads its default rather than NULL from the first flush onward.
Inputs the tree does not declare (dynamic UI, custom JS) stay
auto-NULL as before.
}
\keyword{internal}
