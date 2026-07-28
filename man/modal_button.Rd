% tinyrox says don't edit this manually, but it can't stop you!
\name{modal_button}
\alias{modal_button}
\title{Create a button that closes the modal without telling the server}
\usage{
modal_button(label = "Cancel")
}
\arguments{
\item{label}{character button label}
}
\value{
A UI component
}
\description{
The Cancel case: dismissing a dialog is not usually news. For a
button the server should hear about, use button() and call
remove_modal() from its observer.
}
\examples{
modal_button("Cancel")
}
