% tinyrox says don't edit this manually, but it can't stop you!
\name{render_text}
\alias{render_text}
\title{Render plain text}
\usage{
render_text(fn)
}
\arguments{
\item{fn}{zero-arg function computing the value}
}
\value{
a glinty_renderer for assignment to output$id
}
\description{
The value is coerced to character and set as textContent, so it
is always displayed literally (no HTML injection).
}
\examples{
\dontrun{
output$greeting <- render_text(function() paste("hello", input$name()))
}
}
