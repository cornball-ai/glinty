% tinyrox says don't edit this manually, but it can't stop you!
\name{txt}
\alias{txt}
\title{Display a string}
\usage{
txt(value, variant = "normal", id = NULL)
}
\arguments{
\item{value}{character text to show}

\item{variant}{character "normal", "muted", "strong" or "heading"}

\item{id}{character element ID}
}
\value{
A UI component
}
\description{
Named txt() rather than text() on purpose: text() would mask
graphics::text(), and a glinty app that draws a plot calls that
inside render_plot(). Masking it would break plotting in the one
place glinty most needs it to work. The component is still "text"
on the wire; only the R name gives way.
}
\examples{
txt("Ready.")
txt("optional", variant = "muted")
}
