% tinyrox says don't edit this manually, but it can't stop you!
\name{run_example}
\alias{run_example}
\title{Run a bundled example app}
\usage{
run_example(name, port = 8080L)
}
\arguments{
\item{name}{character example name; omit to list available
examples}

\item{port}{integer HTTP port}
}
\value{
invisible(NULL)
}
\description{
Run a bundled example app
}
\examples{
\dontrun{
run_example("counter")
}
}
