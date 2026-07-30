% tinyrox says don't edit this manually, but it can't stop you!
\name{css_rules}
\alias{css_rules}
\title{Read declarations out of a stylesheet, by selector}
\usage{
css_rules(text)
}
\arguments{
\item{text}{character lines, or one string, of CSS}
}
\value{
list of list(selectors = character, properties = character)
}
\description{
A deliberately small CSS reader, not a CSS parser: comments are
stripped, at-rule bodies are walked into so a media query's contents
count as rules, and declarations are split on `;` and `:`. Enough
for hand-written stylesheets, which is all this is asked to read.
}
\keyword{internal}
