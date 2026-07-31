% tinyrox says don't edit this manually, but it can't stop you!
\name{css_computed_conflicts}
\alias{css_computed_conflicts}
\title{What an app's stylesheet cancels, as the browser resolves it}
\usage{
css_computed_conflicts(path, chrome = NULL, glinty_css = NULL)
}
\arguments{
\item{path}{character path to the app's stylesheet}

\item{chrome}{character browser binary; NULL searches
`GLINTY_CHROME`, then google-chrome and chromium on the PATH}

\item{glinty_css}{character glinty.css contents, for testing this
function itself; read from the installed package when absent}
}
\value{
character vector of findings, empty when there are none
}
\description{
Renders every variant of every family twice -- once under glinty's
stylesheet alone, once with the app's loaded after it, the way a
real page loads them -- and reports each property where variants
the baseline told apart have collapsed to one value.
}
\details{
This is the check `css_variant_conflicts()` documents itself as not
being. It reads the cascade's answer rather than the source, so it
sees `!important`, specificity ties, shorthand against longhand,
and the `:hover` case that motivated it. It needs a browser, and
says so rather than passing when there is none.

States are forced by rewriting `:hover` and friends into classes of
equal specificity, so hover, focus and active are measured
alongside the default state.

}
\examples{
\dontrun{
css <- system.file("app/www/styles.css", package = "myapp")
expect_equal(glinty::css_computed_conflicts(css), character(0))
}
}
