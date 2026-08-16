% tinyrox says don't edit this manually, but it can't stop you!
\docType{data}
\name{KEY_NAMES}
\alias{KEY_NAMES}
\title{The key names every frontend must recognise}
\format{
An object of class \code{character} of length 74.
}
\usage{
KEY_NAMES
}
\description{
Closed for the same reason the icon set is. A browser calls the
escape key "Escape" and Flutter calls it `LogicalKeyboardKey.escape`;
a name outside this set is one each lowering guesses at, and a
shortcut that never fires is invisible in a way a missing button is
not. Enumerated here so a bad name fails where it was written.
}
\details{
Adding one means adding a case to the browser lowering's key map and
to `_keyFor` in dart/glinty_flutter, and the fixtures make that
obligation fail loudly if either is skipped.

Letters are lowercase and digits are the top row: a shortcut names
the key, not the character it would type, so "shift+1" is that and
never "exclam".

}
\keyword{internal}
