% tinyrox says don't edit this manually, but it can't stop you!
\name{merge_theme_colors}
\alias{merge_theme_colors}
\title{Validate colour tokens and merge them over a base palette}
\usage{
merge_theme_colors(base, colors, what)
}
\arguments{
\item{base}{named list of complete default colours}

\item{colors}{named list of supplied colours}

\item{what}{character argument name for errors}
}
\value{
the merged palette, values lowercased
}
\description{
The one loop both palettes go through, so `colors` and `dark` are
held to the same names and the same "#rrggbb(aa)" rule and can
never drift apart.
}
\keyword{internal}
