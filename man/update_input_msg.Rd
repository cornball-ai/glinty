% tinyrox says don't edit this manually, but it can't stop you!
\name{update_input_msg}
\alias{update_input_msg}
\title{Create a typed input-update message}
\usage{
update_input_msg(id, fields)
}
\arguments{
\item{id}{character input ID}

\item{fields}{named list of update fields (value, label, choices,
selected, min, max, step) with NULLs already dropped}
}
\value{
character JSON string
}
\description{
Inputs get typed messages instead of raw DOM patches: the client
applies them widget-aware (skipping a focused element's value,
rebuilding select options) and never re-emits input events.
}
\keyword{internal}
