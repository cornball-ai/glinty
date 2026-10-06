% tinyrox says don't edit this manually, but it can't stop you!
\name{tabset}
\alias{tabset}
\title{Create a tabset}
\usage{
tabset(..., id, selected = NULL)
}
\arguments{
\item{...}{tab_panel() objects}

\item{id}{character input ID reporting the open tab}

\item{selected}{character title of the initially open tab}
}
\value{
A UI component
}
\description{
Given an id the tabset is also an input: its value is the title of
the open tab.
}
\details{
Hidden panels keep their state in the browser and in Flutter, both
of which retain the widgets they are not showing.

The server does not render what nobody can see: an output inside
a hidden panel waits, and renders once when its panel opens, so a
page made of several tools costs the one on screen. While an
output waits, its inputs changing cost nothing, and an
\code{\link{invalidate_later}} inside it is not re-armed. Outputs
built by \code{\link{render_ui}} inside a panel wait with it.
Observers are not suspended; a polling observer that should pause
reads the tabset's input itself.

}
\examples{
tabset(
    tab_panel("Text", verbatim_output("body")),
    tab_panel("Raw", verbatim_output("raw")),
    id = "results"
)
}
