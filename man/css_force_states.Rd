% tinyrox says don't edit this manually, but it can't stop you!
\name{css_force_states}
\alias{css_force_states}
\title{Rewrite state pseudo-classes as classes of equal specificity}
\usage{
css_force_states(css)
}
\arguments{
\item{css}{character stylesheet text}
}
\value{
the same text with state pseudo-classes rewritten
}
\description{
`.g-btn:hover` and `.g-btn.g-force-hover` are both one class plus
one class as far as the cascade is concerned, so swapping them
changes which elements match and nothing else. Pseudo-*elements*
are left alone: `::after` counts as an element, and `:` followed by
`:` never matches these patterns anyway.
}
\keyword{internal}
