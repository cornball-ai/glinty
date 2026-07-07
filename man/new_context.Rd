% tinyrox says don't edit this manually, but it can't stop you!
\name{new_context}
\alias{new_context}
\title{Create a new reactive context}
\usage{
new_context(on_invalidate, label = "")
}
\arguments{
\item{on_invalidate}{function called when this context is invalidated}

\item{label}{character label for debugging}
}
\value{
An environment representing the context
}
\description{
A context tracks a scope of execution. When any reactive source read
during that scope is invalidated, the context's callback fires.
}
\keyword{internal}
