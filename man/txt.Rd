% tinyrox says don't edit this manually, but it can't stop you!
\name{txt}
\alias{txt}
\title{Display a string}
\usage{
txt(value, variant = "normal", id = NULL)
}
\arguments{
\item{value}{character text to show}

\item{variant}{character "normal", "muted", "strong", "heading",
"mono", "small", "success", "warning" or "danger". "mono" is for
values that align by character: timecodes, file listings, hashes.
"small" is fine print. The status trio colors the text from the
theme's semantic tokens -- a pill that says healthy, degraded, or
failing -- and stays semantic: what the colors are is the
theme's decision}

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
