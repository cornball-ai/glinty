% tinyrox says don't edit this manually, but it can't stop you!
\name{scoped}
\alias{scoped}
\title{Proxies that apply a namespace}
\usage{
scoped(ns, input, output, session)
}
\arguments{
\item{ns}{a namespace from \code{\link{namespace}}}

\item{input}{the server function's input proxy}

\item{output}{the server function's output proxy}

\item{session}{the server function's session}
}
\value{
list(input, output, session)
}
\description{
The server-side half of \code{\link{namespace}}: returns `input`,
`output` and `session` proxies under which `input$file`,
`output$table <-`, `download_handler(session, "md", ...)`,
`update_text_input(session, "file", ...)`, the feed verbs and
`path_picker()` all address `ns("...")` ids. `session$ns` is the
namespace, for ids built inside `render_ui()`; everything else on
the session reads and writes through to the real one, so
`session$id`, `session$principal`, `run_job(scope = "session")`
and `on_ended()` behave as before.
}
\details{
The proxies passed in may be the server function's own or ones
already scoped: scoping starts from the real session each time,
and the namespace carries the whole prefix, so nesting is
`scoped(namespace("b", parent = ns), ...)`.

}
\examples{
\dontrun{
ns <- namespace("stt")
ui <- column(file_input(ns("file")), text_output(ns("status")))
server <- function(input, output, session) {
    sc <- scoped(ns, input, output, session)
    sc$output$status <- render_text(function() {
        f <- sc$input$file()
        if (is.null(f)) "waiting" else f$name
    })
}
}
}
