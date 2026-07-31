% tinyrox says don't edit this manually, but it can't stop you!
\name{computed_probe_families}
\alias{computed_probe_families}
\title{One probe element per variant, from the real lowering}
\usage{
computed_probe_families(props)
}
\arguments{
\item{props}{named list: base class -> properties to read}
}
\value{
list of list(component, classes, variants, make, properties)
}
\description{
The markup comes from `component_to_html()` rather than being
written out here, so a change to how a button lowers cannot leave
this probing something the app never renders.
}
\details{
It probes one entry per *component*, not per base class, because
two components can share a base -- button and download_button both
lower to `.g-btn` -- and their probes must not collide. The classes
each one shares across its variants come along for the message.

}
\keyword{internal}
