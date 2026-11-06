# The prompter: a script's spoken words, centered and scrolling up at
# a reading pace, for a window that sits by the camera.
#
# The content is lowered from markdown at build time, the way
# markdown() lowers to rich_text, so a client draws blocks and parses
# nothing. The motion -- play, pace, where the text has got to -- is
# the client's, because a tick that crossed the wire would stutter;
# the settings come back as one input under the id when the user
# changes one, so an app can keep them.

#' A teleprompter
#'
#' The words of \code{text}, centered and scrolling up at \code{pace}
#' words a minute, with the reading line a little above the middle
#' of the view. Markdown headings stay, as the places to take a
#' breath: with \code{pause_at_headings} the scroll stops at each one
#' until play is pressed again. Rules, fenced code and whole-line
#' bracketed markers (\code{[cut to b-roll]}) are notes to the editor,
#' not words to say, and stay out; \code{\link{prompter_blocks}} says
#' exactly what is shown.
#'
#' The client owns the motion. Its bar has play, the pace, the text
#' size, pause-at-headings, the colours, start over and fullscreen.
#' Space plays and pauses, up and down change the pace, plus and
#' minus the text size, Page Up and Page Down jump between headings,
#' Home starts over; the wheel or the scrollbar moves the text by
#' hand. The pace is in words a minute: the whole text passes the
#' reading line in words / pace minutes, whatever the text size or
#' the window's width.
#'
#' Colours are the prompter's own, read from across a room:
#' \code{"system"} is black on white by day and white on black at
#' night, following the client's colour scheme; \code{"light"} and
#' \code{"dark"} hold one.
#'
#' The settings are an input under \code{id}: when the user changes
#' one, \code{input[[id]]} becomes \code{list(pace =, scale =,
#' pause_at_headings =, theme =)}, so an app can keep them and hand
#' them back next time. Until then it is NULL. Where the text has
#' scrolled to is not reported: that is the reader's.
#'
#' @param id character input ID, under which the settings report
#' @param text character the script, in markdown; NULL to give
#'   \code{blocks} directly
#' @param blocks what to show, by default lowered from \code{text}
#'   with \code{\link{prompter_blocks}}; an app with its own script
#'   grammar builds them itself, each a list with \code{kind}
#'   (\code{"heading"} or \code{"speech"}), \code{text}, and for
#'   speech an optional \code{speaker}
#' @param pace integer words a minute, 40 to 400
#' @param scale numeric text size as a multiple of the base, 0.5 to 3
#' @param pause_at_headings logical stop at each heading until play
#' @param theme \code{"system"}, \code{"light"} (black on white) or
#'   \code{"dark"} (white on black)
#' @param height integer pixels, or NULL for the client's default,
#'   most of the window's height
#' @param grow integer flex-grow inside a fill panel, like
#'   \code{column()}
#' @return A UI component
#' @examples
#' prompter("read", "# Opening\n\nHello, and welcome back.")
#' prompter("lines", blocks = list(
#'     list(kind = "heading", text = "Scene 1"),
#'     list(kind = "speech", text = "Where were you?", speaker = "Ada")
#' ), pace = 120L)
#' @export
prompter <- function(id, text = NULL, blocks = prompter_blocks(text),
                     pace = 150L, scale = 1, pause_at_headings = TRUE,
                     theme = "system", height = NULL, grow = NULL) {
    component("prompter", id = id, blocks = blocks, pace = pace,
              scale = scale, pause_at_headings = pause_at_headings,
              theme = theme, height = height, grow = grow)
}

#' What a prompter shows
#'
#' The words to say, in the script's order, and the headings between
#' parts. A markdown heading, its marks dropped, is a heading block.
#' A paragraph (lines up to a blank one, joined with spaces) is one
#' speech block, and so is each list item, its marker dropped. Rules
#' (\code{---}), fenced code and a line that is one bracketed marker
#' (\code{[ANIM zoom in]}) are notes to the editor, not words to say,
#' and are left out; brackets inside a line stay. Emphasis marks,
#' inline code marks and links are reduced to their words. Nothing
#' here names a speaker: that is a script grammar, which an app with
#' one applies itself.
#'
#' @param text character markdown, or NULL
#' @return A list of blocks, each \code{list(kind =, text =)}; empty
#'   when there is nothing to say
#' @examples
#' prompter_blocks("# Intro\n\nHello **world**.\n\n[cut]\n\n- one\n- two")
#' @export
prompter_blocks <- function(text) {
    if (is.null(text)) {
        return(list())
    }
    if (!is.character(text) || length(text) != 1L || is.na(text)) {
        stop("text must be a single string", call. = FALSE)
    }
    out <- list()
    para <- character(0L)
    say <- function(s) {
        s <- prompter_words(s)
        if (nzchar(s)) {
            out[[length(out) + 1L]] <<- list(kind = "speech", text = s)
        }
    }
    flush <- function() {
        if (length(para)) {
            say(paste(para, collapse = " "))
            para <<- character(0L)
        }
    }
    fenced <- FALSE
    for (raw in strsplit(text, "\n", fixed = TRUE)[[1L]]) {
        line <- trimws(raw)
        if (grepl("^(```|~~~)", line)) {
            flush()
            fenced <- !fenced
            next
        }
        if (fenced) {
            next
        }
        if (!nzchar(line)) {
            flush()
            next
        }
        if (grepl("^#{1,6}\\s", line)) {
            flush()
            head <- prompter_words(sub("\\s*#+\\s*$", "",
                                       sub("^#{1,6}\\s+", "", line)))
            if (nzchar(head)) {
                out[[length(out) + 1L]] <- list(kind = "heading", text = head)
            }
            next
        }
        bare <- gsub(" ", "", line, fixed = TRUE)
        if (grepl("^(-{3,}|\\*{3,}|_{3,})$", bare) ||
            grepl("^\\[[^]]*\\]$", line)) {
            flush()
            next
        }
        if (grepl("^([-*+]|[0-9]+[.)])\\s+", line)) {
            flush()
            say(sub("^([-*+]|[0-9]+[.)])\\s+", "", line))
            next
        }
        para <- c(para, sub("^>\\s?", "", line))
    }
    flush()
    out
}

#' The words of a line, with the markup taken out
#'
#' Links and images to their text, inline code and emphasis marks
#' dropped, runs of space folded.
#'
#' @param s character one string
#' @return character
#' @keywords internal
prompter_words <- function(s) {
    s <- gsub("!?\\[([^]]*)\\]\\([^)]*\\)", "\\1", s)
    s <- gsub("`", "", s, fixed = TRUE)
    s <- gsub("\\*\\*|__", "", s)
    s <- gsub("(^|[[:space:](])[*_]([^*_]+)[*_](?=$|[[:space:][:punct:]])",
              "\\1\\2", s, perl = TRUE)
    trimws(gsub("\\s+", " ", s))
}
