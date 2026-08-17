% tinyrox says don't edit this manually, but it can't stop you!
\docType{data}
\name{ICON_NAMES}
\alias{ICON_NAMES}
\title{The icon set every frontend must draw}
\format{
An object of class \code{character} of length 10.
}
\usage{
ICON_NAMES
}
\description{
Closed on purpose. An icon name is a token each frontend supplies
artwork for, so the set has to be small enough that every frontend
can actually carry all of it -- and enumerated here so a name no
frontend draws fails where it was written rather than rendering
nothing at all.
}
\details{
Adding one means adding artwork to `inst/www/glinty.css` and a case
to `_iconFor` in dart/glinty_flutter, and the fixtures make that
obligation fail loudly if either is skipped.

}
\keyword{internal}
