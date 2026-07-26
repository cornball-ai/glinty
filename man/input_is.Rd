% tinyrox says don't edit this manually, but it can't stop you!
\name{input_is}
\alias{input_is}
\title{Test an input's value}
\usage{
input_is(id, values)
}
\arguments{
\item{id}{character input ID}

\item{values}{vector of values to match}
}
\value{
A glinty_condition
}
\description{
TRUE when the input's current value is any of values, which makes
a vector an "is one of" test. Comparison is by string, except that
a logical compares by truthiness, so input_is("save", TRUE) reads a
checkbox correctly.
}
\details{
An input that has never been set matches nothing, so a panel keyed
on an untouched input starts hidden.

}
\examples{
input_is("backend", "openai")
input_is("backend", c("chatterbox", "native"))
input_is("stream_mode", TRUE)
}
