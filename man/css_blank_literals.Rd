% tinyrox says don't edit this manually, but it can't stop you!
\name{css_blank_literals}
\alias{css_blank_literals}
\title{Empty out anything a semicolon or colon can hide inside}
\usage{
css_blank_literals(css)
}
\arguments{
\item{css}{character one string of CSS}
}
\value{
the same string with string and url() contents blanked
}
\description{
Declarations are found by splitting on `;` and `:`, and both appear
inside values that are none of this reader's business:
}
\details{
\preformatted{
background: url("data:image/svg+xml;utf8,<svg/>");
content: ";";
}

glinty's own stylesheet is full of the first: every icon is a
`mask-image` data URI. Split naively, those produce declarations that
are not ones -- `utf8,<svg/>")` read as a property name.

Only those two characters are replaced, each with one space, so the
string keeps its length and the block walker's character counting is
undisturbed. Quoted strings go first, because a url() often holds one.

}
\keyword{internal}
