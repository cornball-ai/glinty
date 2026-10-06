% tinyrox says don't edit this manually, but it can't stop you!
\name{note_dynamic_panels}
\alias{note_dynamic_panels}
\title{Record the panels of a dynamic subtree's ids}
\usage{
note_dynamic_panels(session, slot, tree)
}
\arguments{
\item{session}{a glinty_session}

\item{slot}{character the ui_output's id}

\item{tree}{the rendered subtree, unclassed}
}
\value{
invisible(NULL)
}
\description{
A render_ui() tree is not in the static map; its ids inherit the
slot's conditions plus any tabset inside the subtree. Ids this
slot recorded on an earlier render and no longer contains are
forgotten, so a moved output is not gated by a panel it left.
}
\keyword{internal}
