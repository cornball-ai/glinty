% tinyrox says don't edit this manually, but it can't stop you!
\name{css_variant_components}
\alias{css_variant_components}
\alias{css_variant_families}
\title{The base classes that carry variants, and the variants they carry}
\usage{
css_variant_components()

css_variant_families()
}
\value{
named list: component -> list(component, values, shared,
  telling)
}
\description{
Derived from the lowering: every variant of every component that
has them is rendered, and the classes they all share are the base
while the rest tell them apart.
}
\details{
This used to be a stated table, and the table was wrong. It said
`text`'s variants were `.g-text-muted` and `.g-text-strong`;
`html_text()` emits `g-text g-muted` and `g-text g-strong`. It gave
`divider` a `.g-divider-line`; the line case adds no class at all.
It had no entry for `text_output`, which lowers to `.g-output`
rather than `.g-text`. So `.g-text \{ color: red \}` -- the exact
shape these guards exist to catch -- went unreported, because
`color` was never in the property set being compared.

The tests checked the table against `COMPONENT_SCHEMA`, which is
where the variant *values* come from, so a table built out of those
values agreed with itself and the markup was never consulted. It is
computed from the markup now. Deriving from the *stylesheet* would
still be wrong -- that invents families like `.g-tab-nav` and needs
a blocklist that grows with the CSS -- but the lowering is the
authority on which classes exist, and it is the thing that must not
drift from this.

}
\keyword{internal}
\keyword{Which}
\keyword{classes}
\keyword{tell}
\keyword{each}
\keyword{component's}
\keyword{variants}
\keyword{apart}
\keyword{The}
\keyword{single}
\keyword{derivation}
\keyword{both}
\keyword{guards}
\keyword{read:}
\keyword{what}
\keyword{the}
\keyword{lowering}
\keyword{emits}
\keyword{for}
\keyword{every}
\keyword{variant}
\keyword{of}
\keyword{component}
\keyword{that}
\keyword{has}
\keyword{them,}
\keyword{split}
\keyword{into}
\keyword{they}
\keyword{all}
\keyword{share}
\keyword{and}
\keyword{differ.}
