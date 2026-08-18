# markdown() and rich_text: the subset parser, the runs schema, and
# the HTML lowering. The subset IS the spec -- these tests plus the
# PROTOCOL list are what "supported" means, and anything outside it
# must degrade to literal text rather than error: a transcript renders
# whatever a model emitted.

component <- glinty:::component
md_inline <- glinty:::md_inline

blocks <- function(text) unclass(markdown(text))$children
runs <- function(text) md_inline(text)

# --- the component: schema validation at the wire boundary ---
rt <- rich_text(list(text = "a"), list(text = "b", bold = TRUE))
expect_equal(rt$component, "rich_text")
expect_equal(length(rt$runs), 2L)
expect_true(rt$runs[[2L]]$bold)
# marks are present-and-TRUE or absent: FALSE is dropped from the wire
rt <- rich_text(list(text = "x", bold = FALSE))
expect_false("bold" %in% names(rt$runs[[1L]]))
# refusals: no runs, textless run, junk mark, unknown field
expect_error(component("rich_text", runs = list()), "non-empty")
expect_error(rich_text(list(bold = TRUE)), "text")
expect_error(rich_text(list(text = "x", bold = "yes")), "TRUE or FALSE")
expect_error(rich_text(list(text = "x", color = "red")), "unknown")
# href is scheme-restricted HERE, so no client defends itself
expect_error(rich_text(list(text = "x", href = "javascript:alert(1)")),
             "http")
expect_error(rich_text(list(text = "x", href = "vbscript:x")), "http")
for (ok in c("https://a.b", "http://a.b", "mailto:t@a.b", "#frag",
             "/local")) {
    expect_equal(rich_text(list(text = "x", href = ok))$runs[[1L]]$href, ok)
}

# --- inline: marks, combos, and the canonical merge ---
r <- runs("plain **bold** *it* `code` ~~gone~~")
expect_equal(vapply(r, function(x) x$text, character(1L)),
             c("plain ", "bold", " ", "it", " ", "code", " ", "gone"))
expect_true(r[[2L]]$bold)
expect_true(r[[4L]]$italic)
expect_true(r[[6L]]$code)
expect_true(r[[8L]]$strike)
# nesting flattens to combined marks on flat runs
r <- runs("**bold *both* bold**")
expect_equal(length(r), 3L)
expect_true(r[[2L]]$bold && r[[2L]]$italic)
expect_true(r[[1L]]$bold && is.null(r[[1L]]$italic))
# __ is bold too; _ at word edges is italic; snake_case is not
expect_true(runs("__b__")[[1L]]$bold)
expect_true(runs("_i_")[[1L]]$italic)
expect_equal(runs("a snake_case_name")[[1L]]$text, "a snake_case_name")
# backticks protect their contents from every other delimiter
r <- runs("`**not bold**`")
expect_equal(length(r), 1L)
expect_true(r[[1L]]$code)
expect_equal(r[[1L]]$text, "**not bold**")
# an opener with no closer is literal text, never an error
expect_equal(runs("a ** b")[[1L]]$text, "a ** b")
expect_equal(runs("`half")[[1L]]$text, "`half")
# backslash escapes the delimiters
expect_equal(runs("\\*literal\\*")[[1L]]$text, "*literal*")
# adjacent same-marked runs merge: the canonical wire form
expect_equal(length(runs("**a****b**")), 1L)
expect_equal(runs("**a****b**")[[1L]]$text, "ab")

# --- inline: links ---
r <- runs("see [the site](https://cornball.ai) now")
expect_equal(r[[2L]]$text, "the site")
expect_equal(r[[2L]]$href, "https://cornball.ai")
expect_false("href" %in% names(r[[1L]]))
# marks inside link text survive, href rides every produced run
r <- runs("[**bold** link](https://a.b)")
expect_true(r[[1L]]$bold)
expect_equal(r[[1L]]$href, "https://a.b")
expect_equal(r[[2L]]$href, "https://a.b")
# a scheme the schema would refuse drops to unlinked text -- the
# transcript renders, the attack does not. (The stray paren is the
# nested-parens-in-a-rejected-URL artifact: the URL grammar stops at
# the first close paren, and what is left renders as the literal it
# is. Cosmetic, and only ever on a URL that was already refused.)
r <- runs("[x](javascript:alert(1))")
expect_false(any(vapply(r, function(x) "href" %in% names(x), logical(1L))))
expect_equal(r[[1L]]$text, "x)")

# --- blocks ---
b <- blocks("# One\n## Two\n#### Four\n###### Clamped")
expect_equal(vapply(b, function(x) x$level, integer(1L)), c(1L, 2L, 4L, 4L))
# heading inline marks flatten to plain text (schema: value is string)
expect_equal(blocks("# a **b** c")[[1L]]$value, "a b c")
# paragraphs split on blank lines; single newlines stay inside a run
b <- blocks("line one\nline two\n\npara two")
expect_equal(length(b), 2L)
expect_equal(b[[1L]]$runs[[1L]]$text, "line one\nline two")
# fences lower to mono text, contents untouched
b <- blocks("```\nx <- 1\n**not md**\n```")
expect_equal(b[[1L]]$component, "text")
expect_equal(b[[1L]]$variant, "mono")
expect_equal(b[[1L]]$value, "x <- 1\n**not md**")
# an unclosed fence swallows to the end rather than erroring
expect_equal(blocks("```\ndangling")[[1L]]$value, "dangling")
# rules
expect_equal(blocks("---")[[1L]]$component, "divider")
expect_equal(blocks("***")[[1L]]$component, "divider")
# bullets: marker becomes the bullet, source indent is preserved
b <- blocks("- one\n- **two**\n  - nested")
expect_equal(b[[1L]]$runs[[1L]]$text, "• ")
expect_true(b[[2L]]$runs[[2L]]$bold)
expect_equal(b[[3L]]$runs[[1L]]$text, "  • ")
# ordered lists keep the source numbering
b <- blocks("1. first\n7. seventh")
expect_equal(b[[1L]]$runs[[1L]]$text, "1. ")
expect_equal(b[[2L]]$runs[[1L]]$text, "7. ")
# out-of-subset syntax is literal text, not an error
expect_equal(blocks("> quoted")[[1L]]$runs[[1L]]$text, "> quoted")
# vectors join on newlines; empty input is an empty column
expect_equal(length(blocks(c("a", "", "b"))), 2L)
expect_equal(length(blocks("")), 0L)
expect_error(markdown(42), "character")

# --- the HTML lowering: structure is the wire form ---
html <- glinty:::component_to_html(rich_text(
    list(text = "a "),
    list(text = "b", bold = TRUE, italic = TRUE),
    list(text = "c", code = TRUE),
    list(text = "d", strike = TRUE),
    list(text = "e", href = "https://a.b")))
expect_true(grepl('class="g-richtext"', html, fixed = TRUE))
expect_true(grepl('<span class="g-run g-run-b g-run-i">b</span>', html,
                  fixed = TRUE))
expect_true(grepl('<span class="g-run g-run-c">c</span>', html,
                  fixed = TRUE))
expect_true(grepl('<span class="g-run g-run-s">d</span>', html,
                  fixed = TRUE))
expect_true(grepl('<a class="g-run" href="https://a.b">e</a>', html,
                  fixed = TRUE))
# run text is escaped like every other value
html <- glinty:::component_to_html(rich_text(list(text = "<script>")))
expect_false(grepl("<script>", html, fixed = TRUE))
expect_true(grepl("&lt;script&gt;", html, fixed = TRUE))
