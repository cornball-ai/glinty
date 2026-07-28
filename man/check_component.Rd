% tinyrox says don't edit this manually, but it can't stop you!
\name{check_component}
\alias{check_component}
\title{Validate the fields of a component against each other}
\usage{
check_component(type, out)
}
\arguments{
\item{type}{character component name}

\item{out}{the checked field list}
}
\value{
the field list, adjusted
}
\description{
Per-field checks cannot see their siblings, and a few components
have rules that span two. Run after every field has been checked
and defaulted, so this sees the normalized values.
}
\details{
It also fixes the wire arity where it is not fixed by the field
type. `selected` on a single select is one string; on a multiple
select it is an array, including when the array holds one element
or none. Left to auto_unbox that array would collapse to a bare
string whenever exactly one option was chosen, so a client parsing
it would see a list on Tuesday and a string on Wednesday.

}
\keyword{internal}
