% tinyrox says don't edit this manually, but it can't stop you!
\name{field}
\alias{field}
\title{Declare one component field}
\usage{
field(type, required = FALSE, default = NULL, values = NULL, min = NULL,
      max = NULL)
}
\arguments{
\item{type}{character one of "string", "number", "int", "bool",
"enum", "children", "any"}

\item{required}{logical must be supplied}

\item{default}{value filled in when absent; NULL means the field
stays absent rather than becoming null on the wire}

\item{values}{character allowed values, for type "enum"}

\item{min,max}{numeric bounds, for "int" and "number"}
}
\value{
a field spec
}
\description{
Declare one component field
}
\keyword{internal}
