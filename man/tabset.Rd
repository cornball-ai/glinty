% tinyrox says don't edit this manually, but it can't stop you!
\name{tabset}
\alias{tabset}
\title{Create a tabset}
\usage{
tabset(..., id = NULL, selected = NULL)
}
\arguments{
\item{...}{tab_panel() objects}

\item{id}{character input ID reporting the selected tab, or NULL}

\item{selected}{character title of the initially open tab
(defaults to the first)}
}
\value{
A UI element
}
\description{
Switching tabs is a client-side class toggle, not a round trip, so
panel contents keep their DOM and their inputs keep their values
while hidden. Outputs in a hidden tab still update; they are
merely not visible.
}
\details{
Given an id, the tabset is also an input: its value is the title
of the selected tab, readable as input$id() and seeded at page
load. Without an id it is presentation only.

Tabsets nest: a panel may contain another tabset, and each is
scoped to its own container.

}
\examples{
tabset(
    tab_panel("Text", verbatim_output("transcription")),
    tab_panel("Segments", table_output("segments")),
    id = "results_tabs"
)
}
