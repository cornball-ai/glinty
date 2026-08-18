# Markdown, lowered server-side to the closed vocabulary.
#
# The vocabulary deliberately has no "render this markup" component --
# that is raw_html, the escape hatch. What it gains here is the
# smallest addition that makes markdown expressible: rich_text, a flat
# list of styled runs (the inline half), plus markdown(), a build-time
# lowering of the block half onto components that already exist.
# Nothing markdown-shaped crosses the wire: clients render runs and
# never learn where they came from.
#
# The parser is a hand-written SUBSET, and the subset is the spec
# (PROTOCOL.md lists what is in and out; the fixtures pin it). That is
# deliberate: "whatever a full CommonMark engine does" is exactly the
# cross-client agreement problem this protocol exists to avoid, and
# the traffic this serves -- model output in a transcript -- is
# paragraphs, emphasis, code, links, headings, lists and fences.
# Unrecognized syntax degrades to literal text, never to an error:
# a chat message must render, however mangled its markup.

#' Styled text runs
#'
#' The inline-formatting leaf: a flat list of runs, each a piece of
#' text with optional marks (`bold`, `italic`, `code`, `strike`) and
#' an optional `href` that makes the run a link. Flat on purpose --
#' runs do not nest, so every client renders them without a grammar.
#' Marks combine freely on one run.
#'
#' `href` must be http(s), mailto, `#fragment` or site-relative
#' (`/...`); anything else -- `javascript:` above all -- is refused
#' at construction, so no client has to defend itself.
#'
#' Mostly produced by [markdown()]; build runs directly when the
#' source format is not markdown.
#'
#' @param ... runs: lists with `text` and optional `bold`, `italic`,
#'   `code`, `strike`, `href`
#' @param id character optional ID
#' @return A UI component
#' @examples
#' rich_text(list(text = "plain, then "),
#'           list(text = "bold", bold = TRUE))
#' @export
rich_text <- function(..., id = NULL) {
    component("rich_text", runs = list(...), id = id)
}

#' Markdown as components
#'
#' Parses a documented markdown subset at build time and returns the
#' equivalent component tree -- a [column()] of blocks built from the
#' existing vocabulary plus [rich_text()]. No markdown crosses the
#' wire and no client carries a markdown engine, so both frontends
#' render it for free and identically.
#'
#' The subset: paragraphs with `**bold**`, `*italic*` (or `_..._`),
#' `` `code` ``, `~~strike~~` and `[text](url)`; `#` headings (level
#' capped at 4, inline marks flattened to plain text); fenced code
#' blocks (lowered to `text(variant = "mono")`); `-`/`*`/`+` bullet
#' and `1.` ordered list items (one item per line, source indent
#' preserved); `---` rules (lowered to [divider()]). Backslash
#' escapes the delimiter characters. Everything else -- blockquotes,
#' tables, images, raw HTML -- is out, and renders as the literal
#' text it was written as. A link whose URL fails [rich_text()]'s
#' scheme rule is lowered as its text, unlinked.
#'
#' @param text character markdown source (a single string; vectors
#'   are joined with newlines)
#' @return A UI component: a column of blocks
#' @examples
#' markdown("**bold** and `code`")
#' markdown("# Title\n\nA paragraph with a [link](https://cornball.ai).")
#' @export
markdown <- function(text) {
    if (!is.character(text) || anyNA(text)) {
        stop("markdown() needs character text", call. = FALSE)
    }
    text <- paste(text, collapse = "\n")
    blocks <- md_blocks(text)
    do.call(column, blocks)
}

# ---- block pass ----

#' Split markdown into block components
#' @keywords internal
md_blocks <- function(text) {
    lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
    blocks <- list()
    para <- character(0L)
    flush_para <- function() {
        if (length(para) > 0L) {
            runs <- md_inline(paste(para, collapse = "\n"))
            if (length(runs) > 0L) {
                blocks[[length(blocks) + 1L]] <<- rich_text_runs(runs)
            }
            para <<- character(0L)
        }
    }
    i <- 1L
    while (i <= length(lines)) {
        line <- lines[[i]]
        fence <- regmatches(line, regexec("^```", line))[[1L]]
        if (length(fence) > 0L) {
            flush_para()
            body <- character(0L)
            i <- i + 1L
            while (i <= length(lines) && !grepl("^```\\s*$", lines[[i]])) {
                body <- c(body, lines[[i]])
                i <- i + 1L
            }
            i <- i + 1L # past the closing fence (or the end)
            blocks[[length(blocks) + 1L]] <-
            txt(paste(body, collapse = "\n"), variant = "mono")
            next
        }
        if (grepl("^\\s*$", line)) {
            flush_para()
            i <- i + 1L
            next
        }
        h <- regmatches(line, regexec("^(#{1,6})\\s+(.*)$", line))[[1L]]
        if (length(h) == 3L) {
            flush_para()
            # heading value is a plain string in the schema, so inline
            # marks are flattened to their text -- documented subset
            plain <- paste(vapply(md_inline(h[[3L]]), function(r) r$text,
                                  character(1L)),
                           collapse = "")
            blocks[[length(blocks) + 1L]] <-
            heading(plain, level = min(nchar(h[[2L]]), 4L))
            i <- i + 1L
            next
        }
        if (grepl("^\\s*([-*_])\\s*\\1\\s*\\1[\\s*_-]*$", line, perl = TRUE)) {
            flush_para()
            blocks[[length(blocks) + 1L]] <- divider()
            i <- i + 1L
            next
        }
        li <- regmatches(line,
                         regexec("^(\\s*)([-*+]|\\d+\\.)\\s+(.*)$", line))[[1L]]
        if (length(li) == 4L) {
            flush_para()
            marker <- li[[3L]]
            prefix <- if (grepl("^\\d", marker)) {
                paste0(marker, " ")
            } else {
                "• " # the bullet; the source marker is style
            }
            # source indent rides in front of the prefix: nesting
            # renders as the author wrote it, and pre-wrap keeps it
            runs <- c(list(list(text = paste0(li[[2L]], prefix))),
                      md_inline(li[[4L]]))
            blocks[[length(blocks) + 1L]] <- rich_text_runs(runs)
            i <- i + 1L
            next
        }
        para <- c(para, line)
        i <- i + 1L
    }
    flush_para()
    blocks
}

#' Build a rich_text from an already-parsed run list
#' @keywords internal
rich_text_runs <- function(runs) {
    do.call(rich_text, unname(runs))
}

# ---- inline pass ----

#' Parse inline markdown into flat runs
#'
#' A sequential scanner: literal text up to the next delimiter, then
#' the delimiter's span with its mark added, recursively -- but the
#' OUTPUT is flat, because marks travel as state. An opener with no
#' closer is literal text. Backslash escapes the delimiter set.
#' Adjacent runs with identical marks merge, so the wire form is
#' canonical however the nesting was written.
#'
#' @param s character the inline source
#' @return list of runs (lists with text and marks)
#' @keywords internal
md_inline <- function(s) {
    md_merge_runs(md_scan(s, list()))
}

#' The scanner behind md_inline()
#' @keywords internal
md_scan <- function(s, marks) {
    runs <- list()
    literal <- character(0L)
    emit_literal <- function() {
        if (length(literal) > 0L) {
            runs[[length(runs) + 1L]] <<-
            c(list(text = paste(literal, collapse = "")), marks)
            literal <<- character(0L)
        }
    }
    chars <- strsplit(s, "", fixed = TRUE)[[1L]]
    i <- 1L
    n <- length(chars)
    peek <- function(k) if (i + k <= n) chars[[i + k]] else ""
    while (i <= n) {
        ch <- chars[[i]]
        if (ch == "\\" && peek(1L) %in% c("*", "_", "`", "~", "[", "]",
                "(", ")", "\\")) {
            literal <- c(literal, peek(1L))
            i <- i + 2L
            next
        }
        if (ch == "`") {
            close <- md_find(chars, i + 1L, "`")
            # close > i + 1L: an empty span (``) is literal, and R's
            # (i+1):(close-1) would descend into infinite recursion
            if (close > i + 1L) {
                emit_literal()
                runs[[length(runs) + 1L]] <-
                c(list(text = paste(chars[(i + 1L):(close - 1L)],
                                    collapse = ""),
                        code = TRUE), marks)
                i <- close + 1L
                next
            }
        }
        two <- paste0(ch, peek(1L))
        if (two %in% c("**", "__", "~~")) {
            close <- md_find2(chars, i + 2L, two)
            if (close > 0L && close > i + 2L) {
                emit_literal()
                inner <- paste(chars[(i + 2L):(close - 1L)], collapse = "")
                mark <- if (two == "~~") {
                    list(strike = TRUE)
                } else {
                    list(bold = TRUE)
                }
                runs <- c(runs, md_scan(inner, c(marks, mark)))
                i <- close + 2L
                next
            }
        }
        if (ch %in% c("*", "_")) {
            # `_` only opens at a word edge, or snake_case italicizes
            # itself; `*` is safe to open anywhere
            edge <- ch == "*" || i == 1L || grepl("\\s", chars[[i - 1L]])
            close <- if (edge && !grepl("\\s", peek(1L)) && nzchar(peek(1L))) {
                md_find(chars, i + 1L, ch)
            } else {
                -1L
            }
            if (close > i + 1L && !grepl("\\s", chars[[close - 1L]])) {
                emit_literal()
                inner <- paste(chars[(i + 1L):(close - 1L)], collapse = "")
                runs <- c(runs, md_scan(inner, c(marks, list(italic = TRUE))))
                i <- close + 1L
                next
            }
        }
        if (ch == "[") {
            rest <- paste(chars[i:n], collapse = "")
            m <- regmatches(rest,
                            regexec("^\\[([^]]*)\\]\\(([^)[:space:]]+)\\)", rest))[[1L]]
            if (length(m) == 3L) {
                emit_literal()
                inner <- md_scan(m[[2L]], marks)
                # the href applies to every run the text produced; a
                # URL the schema would refuse drops to unlinked text
                # rather than erroring mid-transcript
                if (md_href_ok(m[[3L]])) {
                    inner <- lapply(inner, function(r) {
                        r$href <- m[[3L]]
                        r
                    })
                }
                runs <- c(runs, inner)
                i <- i + nchar(m[[1L]])
                next
            }
        }
        literal <- c(literal, ch)
        i <- i + 1L
    }
    emit_literal()
    runs
}

#' Position of the next single-char delimiter, or -1
#' @keywords internal
md_find <- function(chars, from, ch) {
    j <- from
    while (j <= length(chars)) {
        if (chars[[j]] == "\\") {
            j <- j + 2L
            next
        }
        if (chars[[j]] == ch) {
            return(j)
        }
        j <- j + 1L
    }
    -1L
}

#' Position of the next two-char delimiter, or -1
#' @keywords internal
md_find2 <- function(chars, from, pair) {
    j <- from
    while (j < length(chars)) {
        if (chars[[j]] == "\\") {
            j <- j + 2L
            next
        }
        if (paste0(chars[[j]], chars[[j + 1L]]) == pair) {
            return(j)
        }
        j <- j + 1L
    }
    -1L
}

#' The href schemes runs accept
#'
#' Shared by the schema validator (which errors: the app wrote that
#' component) and markdown() (which degrades to unlinked text: a
#' transcript must render whatever a model emitted).
#'
#' @keywords internal
md_href_ok <- function(href) {
    is.character(href) && length(href) == 1L && !is.na(href) &&
    grepl("^(https?://|mailto:|#|/)", href)
}

#' Merge adjacent runs whose marks agree
#'
#' The canonical wire form: however the nesting was written, equal
#' formatting is one run. Keeps fixtures and clients from depending
#' on parser internals.
#'
#' @keywords internal
md_merge_runs <- function(runs) {
    if (length(runs) < 2L) {
        return(runs)
    }
    out <- list(runs[[1L]])
    for (r in runs[-1L]) {
        last <- out[[length(out)]]
        same <- identical(last[setdiff(names(last), "text")],
                          r[setdiff(names(r), "text")])
        if (same) {
            last$text <- paste0(last$text, r$text)
            out[[length(out)]] <- last
        } else {
            out[[length(out) + 1L]] <- r
        }
    }
    out
}
