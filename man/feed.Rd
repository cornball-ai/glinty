% tinyrox says don't edit this manually, but it can't stop you!
\name{feed}
\alias{feed}
\title{Create a feed}
\usage{
feed(id, keep = 200L, grow = NULL, width = NULL)
}
\arguments{
\item{id}{character feed ID}

\item{keep}{integer items retained; the window shown and replayed}

\item{grow}{integer flex-grow inside the parent, like column()}

\item{width}{integer fixed width in pixels}
}
\value{
A UI component
}
\description{
A scrolling item log fed by the server: [feed_append()] adds an
item without resending the rest, [feed_patch()] rewrites the newest
(token streaming into the message being generated), [feed_reset()]
replaces the window (history load). A feed starts empty on purpose
-- the server's log is the one source of what it holds -- so an app
loads history with feed_reset() from its server function.
}
\details{
The feed owns its scroll: it stays pinned to the bottom while the
reader is there, releases when they scroll up, and offers a way
back down. `keep` bounds the window; older items fall off the top.

A feed inside a dynamically rendered slot ([render_ui()]) loads
its history from `session$on_flushed()`, not from inside the
render: the shell must reach the client before a [feed_reset()]
aimed at it means anything, and on_flushed fires exactly after the
flush that carried the slot's tree has drained. One reset per slot
render, appends between.

}
\examples{
feed("log")
feed("room", keep = 500L, grow = 1L)
}
