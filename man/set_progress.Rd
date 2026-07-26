% tinyrox says don't edit this manually, but it can't stop you!
\name{set_progress}
\alias{set_progress}
\title{Set the current progress bar directly}
\usage{
set_progress(value = NULL, detail = NULL, message = NULL)
}
\arguments{
\item{value}{numeric fraction between 0 and 1 (NULL leaves it
alone)}

\item{detail}{character new secondary line (NULL leaves it alone)}

\item{message}{character new headline (NULL leaves it alone)}
}
\value{
invisible(NULL)
}
\description{
Like inc_progress() but takes an absolute fraction. Outside a
with_progress() it does nothing.
}
\examples{
\dontrun{
set_progress(0.5, detail = "Halfway")
}
}
