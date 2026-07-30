% tinyrox says don't edit this manually, but it can't stop you!
\name{css_variant_conflicts}
\alias{css_variant_conflicts}
\title{A bare-base-class preflight check, not a cascade validator}
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
variant at equal specificity, silently: nothing fails, and the app
just has one kind of button.
}
\details{
**What it looks at is exactly one shape**: a selector that is a bare
base class, `.g-btn`. Deliberately narrow, because narrow is what
makes it free of false positives -- an app writing `#header .g-btn`
or `.g-btn.g-btn-ghost` is beating a variant on specificity on
purpose, and saying so.

What it therefore does **not** see:

- `.g-btn:hover`, `.g-btn:focus` and any other compound or
pseudo-class selector. A hover rule on the base class really does
overrule a variant's hover, and this will not tell you.
- a conflict in the other direction, where glinty's own stylesheet
overrules something the app set. `.g-image \{ height: auto \}`
beating `image(height = 32)` was that, and this would not have
caught it.
- anything that is not a variant family: layout, spacing, a theme
token overridden to something unreadable.

For those, read the cascade result rather than the source: load the
page in a headless browser and assert `getComputedStyle()`. That
catches every shape and needs a browser; this catches the one shape
that has actually shipped twice and needs nothing.


}
\examples{
\dontrun{
# in inst/tinytest/test_styles.R
css <- system.file("app/www/styles.css", package = "myapp")
expect_equal(glinty::css_variant_conflicts(css), character(0))
}
}
