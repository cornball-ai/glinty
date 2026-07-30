% tinyrox says don't edit this manually, but it can't stop you!
\name{css_variant_families}
\alias{css_variant_families}
\title{The base classes that carry variants, and the variants they carry}
\usage{
css_variant_families()
}
\value{
named list: base class -> its variant classes
}
\description{
Stated, not derived. An earlier version of this read the families out
of glinty.css by looking for `.g-x` with `.g-x-*` siblings, which
invents families that are not ones -- `.g-tab-nav` is a piece of a
tabset rather than a flavour of it, `.g-radio-group` is a container
rather than a kind of radio -- and then needs a blocklist that grows
every time the stylesheet does.
}
\details{
Which classes are a variant family is a fact about the lowering that
emits them (see `html_button`, `html_panel`), so it belongs beside
the lowering. ``css_variant_classes_styled()`` checks this against the
stylesheet, so the two cannot drift apart quietly.

}
\keyword{internal}
