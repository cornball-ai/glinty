% tinyrox says don't edit this manually, but it can't stop you!
\name{print.glinty_job}
\alias{print.glinty_job}
\title{Print a job handle}
\usage{
\method{print}{glinty_job}(x, ...)
}
\arguments{
\item{x}{a glinty_job}

\item{...}{ignored}
}
\value{
x, invisibly
}
\description{
Print a job handle
}
\examples{
\dontrun{
print(run_job(function() 1, scope = "app"))
}
}
