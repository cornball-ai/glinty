% tinyrox says don't edit this manually, but it can't stop you!
\docType{data}
\name{MODAL_CLOSE_ID}
\alias{MODAL_CLOSE_ID}
\title{The one reserved component id}
\format{
An object of class \code{character} of length 1.
}
\usage{
MODAL_CLOSE_ID
}
\description{
A button carrying it closes the open dialog locally and reports
nothing. Reserved rather than app-chosen because ids opening with
".." are refused on the input path, so no app can collide with it.
}
\details{
Both lowerings read this: the browser marks the button with
data-g-modal-close, Flutter checks the id directly. A magic string
either side does not know is a button that renders and does
nothing.

}
\keyword{internal}
