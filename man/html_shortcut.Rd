% tinyrox says don't edit this manually, but it can't stop you!
\name{html_shortcut}
\alias{html_shortcut}
\title{A key binding, lowered to a hidden marker the client binds from}
\usage{
html_shortcut(x)
}
\arguments{
\item{x}{the component}
}
\value{
character HTML
}
\description{
There is no keyboard element in HTML, so the binding rides in the
DOM as data and one delegated listener reads it. That keeps the
bindings in the tree rather than in a registry beside it: a rebuilt
UI has exactly the shortcuts its new tree declares, with none left
over from the old one.
}
\keyword{internal}
