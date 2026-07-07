# Tests for UI constructors

tag_to_html <- getFromNamespace("tag_to_html", "glinty")

# div with class and id
d <- div(h1("Title"), class = "main", id = "root")
expect_equal(d$tag, "div")
expect_equal(d$attrs$class, "main")
expect_equal(d$attrs$id, "root")
expect_equal(length(d$children), 1L)
html <- tag_to_html(d)
expect_true(grepl('class="main"', html))
expect_true(grepl('id="root"', html))
expect_true(grepl("<h1>Title</h1>", html))

# div with no attrs
d2 <- div(h2("Sub"))
expect_equal(length(d2$attrs), 0L)

# select_input
sel <- select_input("backend", "Backend:",
                    choices = c("OpenAI" = "openai", "Local" = "local"),
                    selected = "local")
html <- tag_to_html(sel)
expect_true(grepl("<select", html))
expect_true(grepl('data-g-event="change"', html))
expect_true(grepl('data-g-target="backend"', html))
expect_true(grepl('<option value="openai">OpenAI</option>', html))
expect_true(grepl('selected="selected"', html))

# select_input defaults to first choice
sel2 <- select_input("x", choices = c("a", "b"))
html2 <- tag_to_html(sel2)
expect_true(grepl('<option value="a" selected="selected">a</option>', html2))

# textarea_input
ta <- textarea_input("text", "Enter:", value = "hello", rows = 6L,
                     placeholder = "Type here")
html <- tag_to_html(ta)
expect_true(grepl("<textarea", html))
expect_true(grepl('rows="6"', html))
expect_true(grepl('placeholder="Type here"', html))
expect_true(grepl(">hello</textarea>", html))
expect_true(grepl('data-g-event="input"', html))

# checkbox_input unchecked
cb <- checkbox_input("save", "Save files", value = FALSE)
html <- tag_to_html(cb)
expect_true(grepl('type="checkbox"', html))
expect_true(grepl('data-g-event="change"', html))
expect_false(grepl("checked", html))

# checkbox_input checked
cb2 <- checkbox_input("save", "Save files", value = TRUE)
html2 <- tag_to_html(cb2)
expect_true(grepl('checked="checked"', html2))

# slider_input
sl <- slider_input("speed", "Speed:", min = 0.5, max = 2.0,
                   value = 1.0, step = 0.1)
html <- tag_to_html(sl)
expect_true(grepl('type="range"', html))
expect_true(grepl('min="0.5"', html))
expect_true(grepl('max="2"', html))
expect_true(grepl('value="1"', html))
expect_true(grepl('step="0.1"', html))
expect_true(grepl('data-g-event="input"', html))
# Value display span
expect_true(grepl('id="speed_val"', html))

# number_input
ni <- number_input("k", "Clusters:", value = 3, min = 1, max = 10, step = 1)
html <- tag_to_html(ni)
expect_true(grepl('type="number"', html))
expect_true(grepl('value="3"', html))
expect_true(grepl('min="1"', html))
expect_true(grepl('max="10"', html))
expect_true(grepl('data-g-event="input"', html))
expect_true(grepl('data-g-target="k"', html))

# number_input omits NULL attrs
ni2 <- number_input("k2")
html2 <- tag_to_html(ni2)
expect_false(grepl("value=", html2))
expect_false(grepl("min=", html2))

# text_input placeholder only when given
ti <- text_input("q", placeholder = "Search...")
expect_true(grepl('placeholder="Search..."', tag_to_html(ti), fixed = TRUE))
ti2 <- text_input("q2")
expect_false(grepl("placeholder", tag_to_html(ti2)))

# audio_output
ao <- audio_output("player")
html <- tag_to_html(ao)
expect_equal(html, '<audio id="player" controls="controls" class="g-audio-output"></audio>')

# plot_output is a void img with dimensions
po <- plot_output("scatter", width = 300L, height = 200L)
html <- tag_to_html(po)
expect_true(grepl("<img ", html))
expect_false(grepl("</img>", html))
expect_true(grepl('id="scatter"', html))
expect_true(grepl('width="300"', html))
expect_true(grepl('height="200"', html))

# span
s <- span("hello", class = "status")
expect_equal(s$tag, "span")
expect_equal(s$text, "hello")
html <- tag_to_html(s)
expect_true(grepl('class="status"', html))
expect_true(grepl(">hello</span>", html))

# html_output
ho <- html_output("details")
html <- tag_to_html(ho)
expect_equal(html, '<div id="details" class="g-html-output"></div>')
