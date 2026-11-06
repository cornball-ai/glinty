# The prompter: the lowering from markdown to blocks, the component's
# schema, and the HTML the client must match.

prompter <- glinty::prompter
prompter_blocks <- glinty::prompter_blocks
component <- glinty:::component
component_to_html <- glinty:::component_to_html

# --- blocks: what is said, in order, and the headings between ---
b <- prompter_blocks("# Opening\n\nHello, and **welcome** back.\nSecond line.\n\n[cut to b-roll]\n\n---\n\n## The tools ##\n\n- one\n- two\n\n1. three\n\n> quoted words\n\n```\ncode()\n```\n\nThe end.")
expect_equal(vapply(b, `[[`, "", "kind"),
             c("heading", "speech", "heading", "speech", "speech", "speech",
               "speech", "speech"))
expect_equal(vapply(b, `[[`, "", "text"),
             c("Opening", "Hello, and welcome back. Second line.", "The tools",
               "one", "two", "three", "quoted words", "The end."))
# nothing to say
expect_equal(prompter_blocks(NULL), list())
expect_equal(prompter_blocks(""), list())
expect_equal(prompter_blocks("---\n\n[marker]\n\n```\nx\n```\n"), list())
# a bare # is a word, not an empty heading
expect_equal(prompter_blocks("#")[[1]]$text, "#")
# inline marks and links reduce to their words; brackets inside a
# line stay, those are delivery tags
expect_equal(prompter_blocks("Say *this* and `that`, see [the site](https://x.y) [slowly] now.")[[1]]$text,
             "Say this and that, see the site [slowly] now.")
expect_equal(prompter_blocks("a_b_c and 2*3*4")[[1]]$text, "a_b_c and 2*3*4")
expect_error(prompter_blocks(c("a", "b")), "single string")

# --- the component ---
p <- prompter("read", "# One\n\nTwo words.")
expect_equal(p$component, "prompter")
expect_equal(p$id, "read")
expect_equal(length(p$blocks), 2L)
expect_equal(p$pace, 150L)
expect_equal(p$scale, 1)
expect_true(p$pause_at_headings)
expect_equal(p$theme, "system")
expect_null(p$height)
# blocks given directly, with a speaker
q <- prompter("lines", blocks = list(
    list(kind = "heading", text = "Scene 1"),
    list(kind = "speech", text = "Where were you?", speaker = "Ada")
), pace = 120, scale = 1.5, theme = "dark", pause_at_headings = FALSE,
height = 320L)
expect_equal(q$pace, 120L)
expect_equal(q$blocks[[2]]$speaker, "Ada")
expect_equal(q$height, 320L)
# empty is a state, not an error
expect_equal(prompter("none", blocks = list())$blocks, list())
# bounds and shapes are refused where they are written
expect_error(prompter("x", "a", pace = 10), ">= 40")
expect_error(prompter("x", "a", scale = 5), "<= 3")
expect_error(prompter("x", "a", theme = "sepia"), "one of")
expect_error(prompter("x", blocks = list(list(kind = "song", text = "la"))),
             "heading")
expect_error(prompter("x", blocks = list(list(kind = "speech"))), "text")
expect_error(prompter("x", blocks = list(list(kind = "heading", text = "h",
                                              speaker = "A"))), "no speaker")
expect_error(prompter("x", blocks = list(list(kind = "speech", text = "t",
                                              colour = "red"))), "unknown")
expect_error(prompter("x", blocks = "words"), "list of blocks")

# --- the wire form: blocks are an array, FALSE and NULL ride plainly ---
js <- jsonlite::fromJSON(jsonlite::toJSON(glinty:::unclass_recursive(q),
                                          auto_unbox = TRUE, null = "null"),
                         simplifyVector = FALSE)
expect_equal(length(js$blocks), 2L)
expect_false(js$pause_at_headings)
expect_equal(js$theme, "dark")
empty <- jsonlite::toJSON(glinty:::unclass_recursive(prompter("none", blocks = list())),
                          auto_unbox = TRUE, null = "null")
expect_true(grepl('"blocks":[]', empty, fixed = TRUE))

# --- the HTML lowering, which the client's builder mirrors ---
h <- component_to_html(q)
expect_true(grepl('class="g-prompter g-prompter-dark"', h, fixed = TRUE))
expect_true(grepl('data-g-prompter="lines"', h, fixed = TRUE))
expect_true(grepl('data-g-pace="120"', h, fixed = TRUE))
expect_true(grepl('data-g-scale="1.5"', h, fixed = TRUE))
expect_true(grepl('data-g-pause="0"', h, fixed = TRUE))
expect_true(grepl("--g-prompter-scale:1.5;height:320px", h, fixed = TRUE))
expect_true(grepl('tabindex="0"', h, fixed = TRUE))
expect_true(grepl('<div class="g-prompter-heading">Scene 1</div>', h, fixed = TRUE))
expect_true(grepl('<div class="g-prompter-speaker">Ada</div><p>Where were you?</p>', h, fixed = TRUE))
expect_true(grepl('class="g-prompter-line"', h, fixed = TRUE))
expect_true(grepl('class="g-prompter-play"', h, fixed = TRUE) ||
                grepl('g-prompter-play', h, fixed = TRUE))
expect_true(grepl('<option value="dark" selected="selected">', h, fixed = TRUE))
expect_false(grepl("g-prompter-empty", h, fixed = TRUE))
# no binding attributes: the settings report by the client's own
# hand, and a div must never be harvested as a control
expect_false(grepl("data-g-target", h, fixed = TRUE))
# the empty state is named
h0 <- component_to_html(prompter("none", blocks = list()))
expect_true(grepl("g-prompter-empty", h0, fixed = TRUE))
expect_true(grepl("Nothing to read yet", h0, fixed = TRUE))
# values are escaped on the way out
hx <- component_to_html(prompter("x", blocks = list(list(kind = "speech", text = "<b>hi</b>"))))
expect_false(grepl("<b>", hx, fixed = TRUE))
expect_true(grepl("&lt;b&gt;", hx, fixed = TRUE))
# sized like a column
hg <- component_to_html(prompter("g", "a", grow = 1L))
expect_true(grepl("g-sized", hg, fixed = TRUE))
expect_true(grepl("--g-grow:1", hg, fixed = TRUE))

# --- ids: one prompter per id, like an input ---
ids <- glinty::component_ids(glinty::column(prompter("read", "a"),
                                            glinty::button("read", "x")))
expect_equal(names(ids), c("prompter", "button"))
expect_error(glinty:::check_tree_ids(glinty::column(prompter("read", "a"),
                                                    glinty::text_input("read"))),
             "more than once")

# --- the settings come back as one input, nothing is seeded ---
expect_null(glinty:::input_seed_value(p))
s <- glinty:::new_session("pr1")
glinty:::handle_input(s, "read", list(pace = 160L, scale = 1.2,
                                      pause_at_headings = FALSE, theme = "light"))
v <- glinty::isolate(s$input$read())
expect_equal(v$pace, 160L)
expect_equal(v$theme, "light")
