% tinyrox says don't edit this manually, but it can't stop you!
\name{password_input}
\alias{password_input}
\title{Create a password input}
\usage{
password_input(id, label = "", placeholder = NULL, emit = "live")
}
\arguments{
\item{id}{character input ID}

\item{label}{character label text}

\item{placeholder}{character placeholder text; a good place to name
the environment variable in play, without echoing it}

\item{emit}{character "live" or "settle"}
}
\value{
A UI component
}
\description{
There is deliberately no value argument. A prefilled password is
rendered into the page source in plain text, where masking does
nothing, so a secret put here would be published. Read it
server-side and let an empty field mean "use the configured one".
}
\examples{
password_input("api_key", "API Key:",
               placeholder = "using OPENAI_API_KEY")
}
