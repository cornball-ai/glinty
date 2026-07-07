% tinyrox says don't edit this manually, but it can't stop you!
\name{ws_text_frame}
\alias{ws_text_frame}
\title{Encode a text frame}
\usage{
ws_text_frame(txt, mask = FALSE, key = NULL)
}
\arguments{
\item{txt}{character scalar}

\item{mask}{logical whether to mask (client role)}

\item{key}{raw(4) mask key; random when NULL}
}
\value{
raw frame bytes
}
\description{
Encode a text frame
}
\keyword{internal}
