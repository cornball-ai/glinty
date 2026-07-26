% tinyrox says don't edit this manually, but it can't stop you!
\name{cond_and}
\alias{cond_and}
\title{Combine conditions with logical and}
\usage{
cond_and(...)
}
\arguments{
\item{...}{conditions}
}
\value{
A glinty_condition
}
\description{
Combine conditions with logical and
}
\examples{
cond_and(input_is("backend", "qwen3"), input_is("use_voice_design", TRUE))
}
