% tinyrox says don't edit this manually, but it can't stop you!
\name{env_secrets_in}
\alias{env_secrets_in}
\title{Find environment secrets appearing in text}
\usage{
env_secrets_in(text, min_chars = 8L)
}
\arguments{
\item{text}{character to search (the rendered page, typically)}

\item{min_chars}{integer shortest value worth checking}
}
\value{
character vector of variable names, empty when clean
}
\description{
Reports the names of environment variables whose values occur in
the given text. Only variables that look like secrets are checked:
the name must contain KEY, TOKEN, SECRET, PASSWORD, PASSWD or
CREDENTIAL, and the value must be at least min_chars long, which
keeps short or empty settings from matching by accident.
}
\details{
Only the variable names are ever returned, never the values, so
the result is safe to print, log, or put in a test failure.

run_app() calls this on the rendered page before serving it. Use it
directly to assert the same thing in an app's own tests.

}
\examples{
env_secrets_in("<p>nothing to see</p>")
}
