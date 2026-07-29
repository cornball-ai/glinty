% tinyrox says don't edit this manually, but it can't stop you!
\name{css_variant_properties}
\alias{css_variant_properties}
\title{Properties glinty's variants set, per family}
\usage{
css_variant_properties(css = NULL)
}
\arguments{
\item{css}{character glinty.css contents; read from the installed
package when absent}
}
\value{
named list: base class -> properties its variants set
}
\description{
What an app's base-class rule would cancel. Read from the stylesheet
rather than listed, because *which* properties a variant sets is a
styling decision that changes freely; which classes are variants is
not.
}
\keyword{internal}
