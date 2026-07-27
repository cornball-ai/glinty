% tinyrox says don't edit this manually, but it can't stop you!
\name{component_to_html}
\alias{component_to_html}
\title{Lower a component tree to HTML}
\usage{
component_to_html(x)
}
\arguments{
\item{x}{a glinty_component}
}
\value{
character HTML
}
\description{
Used for the browser's server-rendered first paint. The same tree
also travels to the client as JSON, which builds equivalent DOM;
the two must produce the same result, which is what `ui_revision`
hydration checks at runtime and the shared fixtures check in tests.
}
\keyword{internal}
