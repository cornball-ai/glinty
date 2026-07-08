% tinyrox says don't edit this manually, but it can't stop you!
\name{harvest_native_inputs}
\alias{harvest_native_inputs}
\title{Seed session inputs from the UI tree's initial values}
\usage{
harvest_native_inputs(tg, session)
}
\arguments{
\item{tg}{a glinty_tag (or character, ignored)}

\item{session}{the native session}
}
\value{
invisible(NULL)
}
\description{
The browser client harvests rendered DOM values into its init
message; this is the native equivalent, walking the tag tree for
widget defaults so input$x() matches what the window shows.
}
\keyword{internal}
