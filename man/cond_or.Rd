% tinyrox says don't edit this manually, but it can't stop you!
\name{cond_or}
\alias{cond_or}
\title{Combine conditions with logical or}
\usage{
cond_or(...)
}
\arguments{
\item{...}{conditions}
}
\value{
A glinty_condition
}
\description{
For alternatives on a single input, pass a vector to input_is()
instead; this is for alternatives across different inputs.
}
\examples{
cond_or(input_is("backend", "openai"), input_is("expert_mode", TRUE))
}
