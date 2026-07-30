% tinyrox says don't edit this manually, but it can't stop you!
\name{css_variant_classes_styled}
\alias{css_variant_classes_styled}
\title{Which variant classes glinty's own stylesheet gives a treatment}
\usage{
css_variant_classes_styled(css = NULL)
}
\arguments{
\item{css}{character glinty.css contents; read from the installed
package when absent}
}
\value{
character vector of variant classes the stylesheet styles
}
\description{
Not every variant needs a rule: `.g-btn-default` and `.g-text-normal`
are the unstyled case on purpose. This exists so a variant class that
is *named* here but spelled differently in the stylesheet shows up as
a mismatch rather than as a guard that silently checks nothing.
}
\keyword{internal}
