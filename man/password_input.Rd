% tinyrox says don't edit this manually, but it can't stop you!
\name{password_input}
\alias{password_input}
\title{Create a password input}
\usage{
password_input(id, label = "", value = "", placeholder = "")
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{value}{character initial value}

\item{placeholder}{character placeholder text}
}
\value{
A UI element
}
\description{
Identical to text_input() except the browser masks the characters.
Masking is display only: the value travels over the WebSocket like
any other input, so serve the app over HTTPS if the connection
leaves the machine.
}
\examples{
password_input("api_key", "API Key:")
}
