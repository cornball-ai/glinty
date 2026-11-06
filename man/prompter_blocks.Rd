% tinyrox says don't edit this manually, but it can't stop you!
\name{prompter_blocks}
\alias{prompter_blocks}
\title{What a prompter shows}
\usage{
prompter_blocks(text)
}
\arguments{
\item{text}{character markdown, or NULL}
}
\value{
A list of blocks, each \code{list(kind =, text =)}; empty
  when there is nothing to say
}
\description{
The words to say, in the script's order, and the headings between
parts. A markdown heading, its marks dropped, is a heading block.
A paragraph (lines up to a blank one, joined with spaces) is one
speech block, and so is each list item, its marker dropped. Rules
(\code{---}), fenced code and a line that is one bracketed marker
(\code{[ANIM zoom in]}) are notes to the editor, not words to say,
and are left out; brackets inside a line stay. Emphasis marks,
inline code marks and links are reduced to their words. Nothing
here names a speaker: that is a script grammar, which an app with
one applies itself.
}
\examples{
prompter_blocks("# Intro\n\nHello **world**.\n\n[cut]\n\n- one\n- two")
}
