% tinyrox says don't edit this manually, but it can't stop you!
\name{css_variant_conflicts}
\alias{css_variant_conflicts}
\title{App stylesheet rules that overrule a glinty variant}
\usage{
css_variant_conflicts(path, glinty_css = NULL)
}
\arguments{
\item{path}{character path to the app's stylesheet}

\item{glinty_css}{character glinty.css contents, for testing this
function itself; read from the installed package when absent}
}
\value{
character vector of findings, empty when there are none
}
\description{
glinty emits `g-btn g-btn-<variant>`, and an app stylesheet loads
after glinty's. A rule on the *base* class therefore cancels every
variant at equal specificity, silently: nothing fails, and the page
just has one kind of button.
}
\details{
Call this from an app's tests. An empty result is the passing case.

}
\examples{
\dontrun{
# in inst/tinytest/test_styles.R
css <- system.file("app/www/styles.css", package = "myapp")
expect_equal(glinty::css_variant_conflicts(css), character(0))
}
}
