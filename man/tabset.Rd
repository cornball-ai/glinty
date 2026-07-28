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

}
\examples{
tabset(
    tab_panel("Text", verbatim_output("body")),
    tab_panel("Raw", verbatim_output("raw")),
    id = "results"
)
}
