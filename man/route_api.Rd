% tinyrox says don't edit this manually, but it can't stop you!
\name{route_api}
\alias{route_api}
\title{Route a request through the mounted api}
\usage{
route_api(req, api, auth = NULL)
}
\arguments{
\item{req}{parsed request (with raw body when one was sent)}

\item{api}{the application router (see run_app())}

\item{auth}{the configured verifier, or NULL}
}
\value{
raw HTTP response, or NULL when the router declined
}
\description{
Decodes the request (JSON body, query string, per-request
principal), calls the application router, and encodes its answer.
NULL from the router means "not mine" and falls through to
glinty's own routing.
}
\details{
An error inside the router answers 500 with a generic body; the
condition message goes to the server log via message(), never onto
the wire, where it could carry paths or SQL to a caller we do not
know.

}
\keyword{internal}
