% tinyrox says don't edit this manually, but it can't stop you!
\docType{data}
\name{INPUT_META}
\alias{INPUT_META}
\title{What each input emits, and of what type}
\format{
An object of class \code{list} of length 13.
}
\usage{
INPUT_META
}
\description{
Kept beside the schema rather than inside it because it describes
the component's protocol behaviour, not a field the wire carries.
}
\details{
`message` is which client-to-server message the component produces:
`input` for something whose value the server keeps, `event` for a
discrete action it merely observes. `value_type` is what that
message's value must be, and is what the conformance test holds
both lowerings to.

A select is the one component whose value type depends on a field
rather than only on the component, so it declares both. Saying
only "string" was how a multiple select came to be scalar in three
separate places.

}
\keyword{internal}
