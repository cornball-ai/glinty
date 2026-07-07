% tinyrox says don't edit this manually, but it can't stop you!
\name{with_context}
\alias{with_context}
\title{Execute an expression within a reactive context}
\usage{
with_context(ctx, expr)
}
\arguments{
\item{ctx}{The context environment}

\item{expr}{A function to execute}
}
\value{
The result of expr()
}
\description{
Sets the current context, runs the expression, restores the previous
context. Any reactive reads during expr() register the context as
a dependent.
}
\keyword{internal}
