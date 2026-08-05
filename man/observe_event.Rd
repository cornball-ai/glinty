% tinyrox says don't edit this manually, but it can't stop you!
\name{observe_event}
\alias{observe_event}
\title{Observe a single reactive event}
\usage{
observe_event(
  event_fn,
  handler_fn,
  ignore_init = TRUE,
  ignore_null = TRUE,
  once = FALSE,
  priority = 0L,
  label = ""
)
}
\arguments{
\item{event_fn}{a zero-arg function whose tracked reads define the
event (input$id is already such a function)}

\item{handler_fn}{the handler; zero-arg, or one-arg to receive the
event value}

\item{ignore_init}{skip the run that happens at creation time
(default TRUE)}

\item{ignore_null}{skip runs where the event value is not truthy in
the req() sense (default TRUE)}

\item{once}{destroy the observer after the first handler run
(default FALSE)}

\item{priority}{numeric priority passed to observe()}

\item{label}{character label for debugging}
}
\value{
Invisibly, the observer (with $destroy())
}
\description{
Runs a handler when an event expression changes, without taking
reactive dependencies on anything the handler reads. The event is
typically an input accessor: observe_event(input$go, function() ...).
}
\examples{
clicks <- reactive_val(NULL)
observe_event(clicks, function(n) message("click ", n))
clicks(1)
flush_reactions()
}
