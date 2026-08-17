% tinyrox says don't edit this manually, but it can't stop you!
\name{app_theme}
\alias{app_theme}
\title{Define an app theme}
\usage{
app_theme(
  colors = list(),
  spacing = NULL,
  radius = NULL,
  font = list(),
  dark = NULL
)
}
\arguments{
\item{colors}{named list over primary, on_primary, surface,
background, text, muted, border, danger; values are
"#rrggbb" (or "#rrggbbaa") strings}

\item{spacing}{numeric base spacing unit in logical pixels;
spacer() sizes are multiples of it}

\item{radius}{numeric corner radius in logical pixels}

\item{font}{named list over body, mono (font family names) and
size (numeric, logical pixels)}

\item{dark}{named list like `colors`, applied when the system
prefers a dark scheme; partial values merge over glinty's dark
defaults, so `dark = list()` is exactly the stock dark palette.
Merging never reaches across schemes: a light `primary` says
nothing about the dark one, because a colour tuned for a white
surface is not a preference about black -- brand colour in dark
means setting `dark$primary`. NULL (the default) keeps the
supplied theme exact in both schemes}
}
\value{
a glinty_theme
}
\description{
A closed set of semantic tokens, sent once in `welcome` and applied
by every frontend: the browser emits them as CSS custom properties
(and the served page carries them inline, so the first paint is
already themed), a Flutter client maps them onto ThemeData.
Partial arguments merge over glinty's defaults, so
`app_theme(colors = list(primary = "#7c3aed"))` changes one thing.
}
\details{
An app with no theme gets each frontend's own defaults instead --
in the browser that includes the stylesheet's automatic dark mode,
which a supplied theme without `dark` replaces with exactly its
tokens, in both schemes. Supplying `dark` keeps automatic dark
mode: the frontend applies `colors` normally and `dark` when the
system prefers a dark scheme. There is no third state -- the
choice follows the system setting, and an app that supplies only
one palette renders it everywhere, which is today's behaviour and
stays available on purpose.

Named app_theme() rather than theme() for the same reason text()
became txt(): theme() would mask ggplot2::theme() the moment an
app draws a styled plot, and breaking plotting is the one cost
glinty must never charge.

}
\examples{
app_theme(colors = list(primary = "#7c3aed"), radius = 10)
app_theme(colors = list(primary = "#7c3aed"),
          dark = list(primary = "#a78bfa"))
}
