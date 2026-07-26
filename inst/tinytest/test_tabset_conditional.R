tag_to_html <- glinty:::tag_to_html
condition_json <- glinty:::condition_json

# --- password_input mirrors text_input but masks ---
pw <- password_input("api_key", "API Key:", placeholder = "sk-...")
expect_equal(pw$tag, "div")
input_el <- pw$children[[2]]
expect_equal(input_el$attrs$type, "password")
expect_equal(input_el$attrs$id, "api_key")
expect_equal(input_el$attrs$placeholder, "sk-...")
expect_equal(input_el$bind$event, "input")
expect_equal(input_el$bind$target, "api_key")
# no placeholder attribute when none was given
expect_null(password_input("k", "K")$children[[2]]$attrs$placeholder)

# --- verbatim_output is a pre patched on textContent ---
vo <- verbatim_output("raw")
expect_equal(vo$tag, "pre")
expect_equal(vo$attrs$id, "raw")
expect_true(grepl("<pre", tag_to_html(vo), fixed = TRUE))

# --- tab_panel validation ---
expect_error(tab_panel(""), "non-empty")
expect_error(tab_panel(c("a", "b")), "non-empty")
tp <- tab_panel("Text", h1("hi"))
expect_equal(tp$title, "Text")
expect_equal(length(tp$children), 1L)

# --- tabset structure ---
ts <- tabset(
    tab_panel("Text", verbatim_output("transcription")),
    tab_panel("Segments", table_output("segments")),
    tab_panel("Raw", verbatim_output("raw")),
    id = "results_tabs"
)
expect_equal(ts$attrs$id, "results_tabs")
expect_equal(ts$attrs$class, "g-tabset")
nav <- ts$children[[1]]
bodies <- ts$children[[2]]
expect_equal(length(nav$children), 3L)
expect_equal(length(bodies$children), 3L)

# first tab is open by default, the rest hidden
expect_equal(nav$children[[1]]$attrs$class, "g-tab-btn g-tab-active")
expect_equal(nav$children[[2]]$attrs$class, "g-tab-btn")
expect_equal(bodies$children[[1]]$attrs$class, "g-tab-body")
expect_equal(bodies$children[[2]]$attrs$class, "g-tab-body g-hidden")

# buttons carry the panel name and, with an id, a value-carrying bind
expect_equal(nav$children[[1]]$attrs[["data-g-tab-panel"]], "Text")
expect_equal(nav$children[[2]]$bind$target, "results_tabs")
expect_equal(nav$children[[2]]$bind$value, "Segments")
expect_equal(nav$children[[2]]$bind$event, "click")

# bodies keep their children
expect_equal(bodies$children[[2]]$children[[1]]$attrs$id, "segments")

# --- selected picks a different starting tab ---
ts2 <- tabset(tab_panel("A", h1("a")), tab_panel("B", h1("b")),
              selected = "B")
expect_equal(ts2$children[[1]]$children[[1]]$attrs$class, "g-tab-btn")
expect_equal(ts2$children[[1]]$children[[2]]$attrs$class,
             "g-tab-btn g-tab-active")
expect_equal(ts2$children[[2]]$children[[1]]$attrs$class,
             "g-tab-body g-hidden")

# --- without an id the tabset is presentation only ---
ts3 <- tabset(tab_panel("A", h1("a")))
expect_null(ts3$attrs$id)
expect_null(ts3$children[[1]]$children[[1]]$bind)

# --- tabset validation ---
expect_error(tabset(), "at least one")
expect_error(tabset(h1("not a panel")), "tab_panel")
expect_error(tabset(tab_panel("A", h1("a")), tab_panel("A", h1("b"))),
             "unique")
expect_error(tabset(tab_panel("A", h1("a")), selected = "Nope"),
             "selected must name")

# --- conditions serialize to the shape the client evaluates ---
expect_equal(condition_json(input_is("backend", "openai")),
             '{"op":"is","id":"backend","values":["openai"]}')
# a vector is an is-one-of test, and stays an array at length 1
expect_equal(condition_json(input_is("backend", c("chatterbox", "native"))),
             '{"op":"is","id":"backend","values":["chatterbox","native"]}')
expect_equal(condition_json(input_is("stream_mode", TRUE)),
             '{"op":"is","id":"stream_mode","values":[true]}')
expect_equal(condition_json(cond_not(input_is("backend", "openai"))),
             '{"op":"not","arg":{"op":"is","id":"backend","values":["openai"]}}')

nested <- cond_not(cond_and(
    input_is("backend", "qwen3"),
    input_is("use_voice_design", TRUE)
))
expect_equal(
    condition_json(nested),
    paste0('{"op":"not","arg":{"op":"and","args":[',
           '{"op":"is","id":"backend","values":["qwen3"]},',
           '{"op":"is","id":"use_voice_design","values":[true]}]}}')
)

# names on the values vector must not leak into the JSON
expect_equal(condition_json(input_is("b", c(Fast = "fast"))),
             '{"op":"is","id":"b","values":["fast"]}')

# --- condition validation ---
expect_error(input_is("", "x"), "non-empty")
expect_error(input_is("id", character(0)), "at least one value")
expect_error(cond_and(), "at least one")
expect_error(cond_and(input_is("a", "1"), "nope"), "must all be conditions")
expect_error(cond_not("nope"), "expects a condition")

# --- conditional_panel wraps children and carries the condition ---
cp <- conditional_panel(
    text_input("api_base", "API URL:"),
    condition = input_is("backend", "openai")
)
expect_equal(cp$tag, "div")
expect_equal(cp$attrs$class, "g-conditional")
expect_equal(cp$attrs[["data-g-cond"]],
             '{"op":"is","id":"backend","values":["openai"]}')
expect_equal(length(cp$children), 1L)

# the condition survives HTML escaping as valid JSON in an attribute
html <- tag_to_html(cp)
expect_true(grepl("data-g-cond=", html, fixed = TRUE))
expect_true(grepl("&quot;op&quot;", html, fixed = TRUE))
expect_false(grepl('data-g-cond="{"', html, fixed = TRUE))

# children render inside, and are NOT hidden server-side: the client
# decides visibility, so nothing is destroyed or rebuilt
expect_true(grepl('id="api_base"', html, fixed = TRUE))
expect_false(grepl("g-hidden", html, fixed = TRUE))

expect_error(conditional_panel(h1("x")), "needs a condition")
expect_error(conditional_panel(h1("x"), condition = "backend == 'a'"),
             "needs a condition")
