% tinyrox says don't edit this manually, but it can't stop you!
\name{component_fixtures}
\alias{component_fixtures}
\title{Component fixtures every lowering must handle}
\usage{
component_fixtures()
}
\value{
list of fixtures
}
\description{
Each entry is list(name, component, notes). Lowering tests iterate
this, so adding a component here obliges every frontend to answer
for it -- render it, or refuse it by name.
}
\keyword{internal}
