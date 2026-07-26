% tinyrox says don't edit this manually, but it can't stop you!
\name{tab_panel}
\alias{tab_panel}
\title{Create a tab panel}
\usage{
tab_panel(title, ...)
}
\arguments{
\item{title}{character tab label, also the value reported to the
server when the tab is selected. Titles must be unique within a
tabset.}

\item{...}{child elements}
}
\value{
A glinty_tab_panel
}
\description{
One labelled page of a tabset(). Not a UI element on its own; it
only means anything inside tabset().
}
\examples{
tab_panel("Text", verbatim_output("transcription"))
}
