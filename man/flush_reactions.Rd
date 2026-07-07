% tinyrox says don't edit this manually, but it can't stop you!
\name{flush_reactions}
\alias{flush_reactions}
\title{Execute all pending observers}
\usage{
flush_reactions()
}
\value{
invisible(NULL)
}
\description{
Drains the pending queue in priority order (higher priority first).
Each observer re-runs, which may invalidate others and add them
to the queue.
}
\examples{
rv <- reactive_val(1)
observe(function() rv())
rv(2)
flush_reactions()
}
