% tinyrox says don't edit this manually, but it can't stop you!
\name{text_output}
\alias{text_output}
\title{Create a text output slot}
\usage{
text_output(id, variant = "normal")
}
\arguments{
\item{id}{character output ID}

\item{variant}{character "normal", "muted", "strong", "heading",
"mono", "small", "success", "warning" or "danger". "mono" is for
values that align by character: timecodes, file listings, hashes.
"small" is fine print. The status trio colors the value from the
theme's semantic tokens -- the live health readout shape}
}
\value{
A UI component
}
\description{
Create a text output slot
}
\examples{
text_output("greeting")
}
