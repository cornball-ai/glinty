% tinyrox says don't edit this manually, but it can't stop you!
\name{panel}
\alias{panel}
\title{Group children in a container}
\usage{
panel(
  ...,
  variant = "plain",
  title = NULL,
  grow = NULL,
  width = NULL,
  fill = FALSE,
  id = NULL
)
}
\arguments{
\item{...}{child components}

\item{variant}{character "plain", "card" or "sidebar"}

\item{title}{character heading shown above the contents}

\item{grow}{integer share of the parent's spare space; 0 or NULL
takes none}

\item{width}{integer fixed width in pixels}

\item{fill}{logical hand the panel's height to its children, so one
of them can grow into it. Without it a panel is as tall as its
content and a child's `grow` has nothing to take}

\item{id}{character element ID}
}
\value{
A UI component
}
\description{
Group children in a container
}
\examples{
panel(txt("body"), variant = "card", title = "Results")
panel(column(text_output("log"), grow = 1L, scroll = TRUE),
      fill = TRUE)
}
