% tinyrox says don't edit this manually, but it can't stop you!
\name{rich_text}
\alias{rich_text}
\title{Styled text runs}
\usage{
rich_text(..., id = NULL)
}
\arguments{
\item{...}{runs: lists with `text` and optional `bold`, `italic`,
`code`, `strike`, `href`}

\item{id}{character optional ID}
}
\value{
A UI component
}
\description{
The inline-formatting leaf: a flat list of runs, each a piece of
text with optional marks (`bold`, `italic`, `code`, `strike`) and
an optional `href` that makes the run a link. Flat on purpose --
runs do not nest, so every client renders them without a grammar.
Marks combine freely on one run.
}
\details{
`href` must be http(s), mailto, `#fragment` or site-relative
(`/...`); anything else -- `javascript:` above all -- is refused
at construction, so no client has to defend itself.

Mostly produced by [markdown()]; build runs directly when the
source format is not markdown.

}
\examples{
rich_text(list(text = "plain, then "),
          list(text = "bold", bold = TRUE))
}
