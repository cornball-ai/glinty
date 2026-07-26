% tinyrox says don't edit this manually, but it can't stop you!
\name{inc_progress}
\alias{inc_progress}
\title{Advance the current progress bar}
\usage{
inc_progress(amount = 0.1, detail = NULL, message = NULL)
}
\arguments{
\item{amount}{numeric fraction to add}

\item{detail}{character new secondary line (NULL leaves it alone)}

\item{message}{character new headline (NULL leaves it alone)}
}
\value{
invisible(NULL)
}
\description{
Adds amount to the bar opened by the innermost enclosing
with_progress(). Outside one it does nothing, so instrumented code
stays callable from a plain script.
}
\examples{
\dontrun{
inc_progress(0.2, detail = "Converting audio")
}
}
