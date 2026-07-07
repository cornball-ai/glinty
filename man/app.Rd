% tinyrox says don't edit this manually, but it can't stop you!
\name{app}
\alias{app}
\title{Define a glinty application}
\usage{
app(ui, server)
}
\arguments{
\item{ui}{a UI tree from page() etc.}

\item{server}{a function(input, output) or
function(input, output, session) defining reactive logic; it is
called once per connecting browser tab, each with its own
session-scoped state}
}
\value{
A glinty_app object
}
\description{
Define a glinty application
}
\examples{
app_obj <- app(
    ui = page(
        text_input("name", "Name:"),
        text_output("greeting")
    ),
    server = function(input, output) {
        output$greeting <- render_text(function() {
            paste("Hello,", input$name())
        })
    }
)
}
