% tinyrox says don't edit this manually, but it can't stop you!
\name{write_fixture_json}
\alias{write_fixture_json}
\title{Regenerate the checked-in fixture JSON}
\usage{
write_fixture_json(path = "inst/fixtures/components.json")
}
\arguments{
\item{path}{character destination; defaults to the source tree}
}
\value{
the path, invisibly
}
\description{
Run after changing component_fixtures(). A test compares the file
against fixture_json() and fails on drift, so the JSON cannot
silently fall behind the R definition.
}
\keyword{internal}
