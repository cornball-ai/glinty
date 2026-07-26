% tinyrox says don't edit this manually, but it can't stop you!
\name{download_button}
\alias{download_button}
\title{Create a download button}
\usage{
download_button(id, label = "Download", class = NULL)
}
\arguments{
\item{id}{character download ID}

\item{label}{character button label}

\item{class}{character extra CSS class(es)}
}
\value{
A UI element
}
\description{
Renders a link the client points at this session's download route
once it knows its session id. The id must match a
download_handler() registered on the server.
}
\examples{
download_button("download_audio", "Download")
}
