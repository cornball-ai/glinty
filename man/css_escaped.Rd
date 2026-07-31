% tinyrox says don't edit this manually, but it can't stop you!
\name{css_escaped}
\alias{css_escaped}
\title{Is the character at this position escaped?}
\usage{
css_escaped(chars, i)
}
\arguments{
\item{chars}{character vector of single characters}

\item{i}{integer position to test}
}
\value{
logical
}
\description{
By counting the backslashes before it, not by looking at one. An
odd number escapes it; an even number means they escaped each other
and this character is structural. The difference matters twice in
the same scanner: `"a\\"` ends its string (two backslashes, then a
real closing quote), and `.icon\:hover` is a class name with a
colon in it rather than a pseudo-class.
}
\keyword{internal}
