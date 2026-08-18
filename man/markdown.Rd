% tinyrox says don't edit this manually, but it can't stop you!
\name{markdown}
\alias{markdown}
\title{Markdown as components}
\usage{
markdown(text)
}
\arguments{
\item{text}{character markdown source (a single string; vectors
are joined with newlines)}
}
\value{
A UI component: a column of blocks
}
\description{
Parses a documented markdown subset at build time and returns the
equivalent component tree -- a [column()] of blocks built from the
existing vocabulary plus [rich_text()]. No markdown crosses the
wire and no client carries a markdown engine, so both frontends
render it for free and identically.
}
\details{
The subset: paragraphs with `**bold**`, `*italic*` (or `_..._`),
`` `code` ``, `~~strike~~` and `[text](url)`; `#` headings (level
capped at 4, inline marks flattened to plain text); fenced code
blocks (lowered to `text(variant = "mono")`); `-`/`*`/`+` bullet
and `1.` ordered list items (one item per line, source indent
preserved); `---` rules (lowered to [divider()]). Backslash
escapes the delimiter characters. Everything else -- blockquotes,
tables, images, raw HTML -- is out, and renders as the literal
text it was written as. A link whose URL fails [rich_text()]'s
scheme rule is lowered as its text, unlinked.

}
\examples{
markdown("**bold** and `code`")
markdown("# Title\n\nA paragraph with a [link](https://cornball.ai).")
}
