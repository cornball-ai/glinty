% tinyrox says don't edit this manually, but it can't stop you!
\name{prompter}
\alias{prompter}
\title{A teleprompter}
\usage{
prompter(
  id,
  text = NULL,
  blocks = prompter_blocks(text),
  pace = 150L,
  scale = 1,
  pause_at_headings = TRUE,
  theme = "system",
  height = NULL,
  grow = NULL
)
}
\arguments{
\item{id}{character input ID, under which the settings report}

\item{text}{character the script, in markdown; NULL to give
\code{blocks} directly}

\item{blocks}{what to show, by default lowered from \code{text}
with \code{\link{prompter_blocks}}; an app with its own script
grammar builds them itself, each a list with \code{kind}
(\code{"heading"} or \code{"speech"}), \code{text}, and for
speech an optional \code{speaker}}

\item{pace}{integer words a minute, 40 to 400}

\item{scale}{numeric text size as a multiple of the base, 0.5 to 3}

\item{pause_at_headings}{logical stop at each heading until play}

\item{theme}{\code{"system"}, \code{"light"} (black on white) or
\code{"dark"} (white on black)}

\item{height}{integer pixels, or NULL for the client's default,
most of the window's height}

\item{grow}{integer flex-grow inside a fill panel, like
\code{column()}}
}
\value{
A UI component
}
\description{
The words of \code{text}, centered and scrolling up at \code{pace}
words a minute, with the reading line a little above the middle
of the view. Markdown headings stay, as the places to take a
breath: with \code{pause_at_headings} the scroll stops at each one
until play is pressed again. Rules, fenced code and whole-line
bracketed markers (\code{[cut to b-roll]}) are notes to the editor,
not words to say, and stay out; \code{\link{prompter_blocks}} says
exactly what is shown.
}
\details{
The client owns the motion. Its bar has play, the pace, the text
size, pause-at-headings, the colours, start over and fullscreen.
Space plays and pauses, up and down change the pace, plus and
minus the text size, Page Up and Page Down jump between headings,
Home starts over; the wheel or the scrollbar moves the text by
hand. The pace is in words a minute: the whole text passes the
reading line in words / pace minutes, whatever the text size or
the window's width.

Colours are the prompter's own, read from across a room:
\code{"system"} is black on white by day and white on black at
night, following the client's colour scheme; \code{"light"} and
\code{"dark"} hold one.

The settings are an input under \code{id}: when the user changes
one, \code{input[[id]]} becomes \code{list(pace =, scale =,
pause_at_headings =, theme =)}, so an app can keep them and hand
them back next time. Until then it is NULL. Where the text has
scrolled to is not reported: that is the reader's.

}
\examples{
prompter("read", "# Opening\n\nHello, and welcome back.")
prompter("lines", blocks = list(
    list(kind = "heading", text = "Scene 1"),
    list(kind = "speech", text = "Where were you?", speaker = "Ada")
), pace = 120L)
}
