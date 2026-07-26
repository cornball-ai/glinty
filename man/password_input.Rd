% tinyrox says don't edit this manually, but it can't stop you!
\name{password_input}
\alias{password_input}
\title{Create a password input}
\usage{
password_input(id, label = "", placeholder = "")
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{placeholder}{character placeholder text; a good place to say
which environment variable is in play, without echoing it}
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
\details{
There is deliberately no value argument. A value= attribute is
rendered into the page source in plain text, where the masking does
nothing, so prefilling a password field from a secret publishes it
to anyone who can fetch the page. Read the secret server-side
instead and let an empty field mean "use the configured one".

}
\examples{
password_input("api_key", "API Key:",
               placeholder = "using OPENAI_API_KEY (type to override)")
}
