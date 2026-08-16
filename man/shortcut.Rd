% tinyrox says don't edit this manually, but it can't stop you!
\name{shortcut}
\alias{shortcut}
\title{Bind a key to an event}
\usage{
shortcut(id, key, value = NULL, typing = FALSE, hold = FALSE)
}
\arguments{
\item{id}{character event ID, as a `button()`'s would be}

\item{key}{character key spec: an optional `ctrl`/`shift`/`alt`
(or `cmd`/`meta`/`option`) prefix joined by `+`, then one key}

\item{value}{character carried on the event, exactly as a button's
is, so one handler can serve several bindings}

\item{typing}{logical fire even while a text input has focus}

\item{hold}{logical fire repeatedly while the key is held, for
shortcuts that nudge rather than toggle}
}
\value{
A UI component
}
\description{
A shortcut is a button you cannot see. It emits the same event frame
a `button()` does, so `observe_event(input$id, ...)` serves both and
one id can carry the visible control and its accelerator together.
}
\details{
It renders nothing. Put it anywhere in the tree; a client that has
never heard of it says so where it sits, which is the point of
putting it in the tree rather than smuggling it in as a script.

`key` is a spec like `"ctrl+shift+k"`, `"space"` or `"f5"`, parsed
here into the fields the wire carries. `ctrl` also means Command on a
Mac: an app that means "the platform's command modifier" should not
have to say it twice.

By default a shortcut does NOT fire while a text field has focus,
because the alternative is `d` deleting a clip halfway through typing
a filename. Escape and the function keys usually want `typing = TRUE`.

A shortcut takes the keypress: the browser's own binding for it does
not also run. Bind `ctrl+s` and it saves the project rather than
offering to save the page.

}
\examples{
shortcut("play", "space")
shortcut("save_project", "ctrl+s", typing = TRUE)
shortcut("nudge_left", "left", hold = TRUE)
}
